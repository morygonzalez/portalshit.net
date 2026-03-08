# frozen_string_literal: true
require 'activerecord-import'

ENV['NEWRELIC_AGENT_ENABLED'] = 'false'

module SimilarEntriesTask
  @stale_entry_ids = []

  class << self
    attr_accessor :stale_entry_ids
  end
end

class ExecutionDetector
  attr_reader :force, :message

  def initialize(arguments: {})
    @force = arguments[:force]
  end

  def run_execution?
    case
    when force.present? && force == 'true'
      SimilarEntriesTask.stale_entry_ids = Entry.published.pluck(:id)
      @message = "Force execution: processing all #{SimilarEntriesTask.stale_entry_ids.count} entries."
      true
    when Similarity.count.zero? || EntryTermFrequency.count.zero?
      SimilarEntriesTask.stale_entry_ids = Entry.published.pluck(:id)
      @message = 'Run execution because there is no similarity/term frequency records.'
      true
    when stale_entry_ids.empty?
      @message = 'Skip: no entries have been updated since last run.'
      false
    else
      SimilarEntriesTask.stale_entry_ids = stale_entry_ids
      @message = "Updating similarity for #{stale_entry_ids.count} changed entries..."
      true
    end
  end

  private

  def stale_entry_ids
    @stale_entry_ids ||= begin
      tokenized_at = EntryTermFrequency
        .select('entry_id, MAX(entry_updated_at) as last_tokenized_at')
        .group(:entry_id)
        .each_with_object({}) { |r, h| h[r.entry_id] = r.last_tokenized_at }

      Entry.published.pluck(:id, :updated_at).filter_map { |id, updated_at|
        id if tokenized_at[id].nil? || tokenized_at[id] < updated_at
      }
    end
  end
end

desc 'Detect and update similar entries'
task :similar_entries, :force do |task, arguments|
  detector = ExecutionDetector.new(arguments: arguments)
  if detector.run_execution?
    puts detector.message
    Rake::Task[:'similar_entries:extract_term'].invoke
    Rake::Task[:'similar_entries:vector_normalize'].invoke
    Rake::Task[:'similar_entries:export'].invoke
  else
    puts detector.message
    next
  end
end

namespace :similar_entries do
  def db
    @db ||= begin
              require 'sqlite3'
              SQLite3::Database.new(':memory:')
            end
  end

  desc 'Extract term'
  task :extract_term do
    stale_ids = SimilarEntriesTask.stale_entry_ids

    create_table_sql = <<~SQL
      DROP TABLE IF EXISTS tfidf;
      CREATE TABLE tfidf (
        `id` INTEGER PRIMARY KEY,
        `term` TEXT NOT NULL,
        `entry_id` INTEGER NOT NULL,
        `term_count` INTEGER NOT NULL DEFAULT 0, -- エントリ内でのターム出現回数
        `tfidf` FLOAT NOT NULL DEFAULT 0, -- 正規化前の TF-IDF
        `tfidf_n` FLOAT NOT NULL DEFAULT 0 -- ベクトル正規化した TF-IDF
      );
      CREATE UNIQUE INDEX index_tf_term ON tfidf (`term`, `entry_id`);
      CREATE INDEX index_tf_entry_id ON tfidf (`entry_id`);
    SQL
    db.execute_batch(create_table_sql)

    # stale なエントリだけ再トークナイズして MySQL に保存
    if stale_ids.present?
      EntryTermFrequency.where(entry_id: stale_ids).delete_all

      new_frequencies = []
      Entry.includes(:category, :tags).published.where(id: stale_ids).find_each(batch_size: 100) do |entry|
        text_to_tokenize = <<~HEREDOC.strip_heredoc
          #{entry.title}
          #{entry.raw_body})
          #{entry.category&.title}
          #{entry.tag_list.join(' ')}
        HEREDOC
        words = Tokenizer.run(text_to_tokenize)
        frequency = words.each_with_object(Hash.new(0)) { |word, sum| sum[word] += 1 }
        frequency.each do |word, count|
          new_frequencies << EntryTermFrequency.new(
            entry_id: entry.id,
            term: word,
            term_count: count,
            entry_updated_at: entry.updated_at
          )
        end
      end

      EntryTermFrequency.import new_frequencies if new_frequencies.any?
    end

    # MySQL の全 term frequency を SQLite に一括ロード
    db.transaction do
      stmt = db.prepare('INSERT INTO tfidf (term, entry_id, term_count) VALUES (?, ?, ?)')
      EntryTermFrequency.select(:term, :entry_id, :term_count).find_each(batch_size: 1000) do |etf|
        stmt.execute(etf.term, etf.entry_id, etf.term_count)
      end
      stmt.close
    end
  end

  desc 'Vector Normalize'
  task :vector_normalize do
    libsqlite_path = if ENV['LIBSQLITE_PATH']
                       ENV['LIBSQLITE_PATH']
                     elsif RUBY_PLATFORM.match?(/darwin/)
                       '/usr/local/lib/libsqlitefunctions.dylib'
                     elsif RUBY_PLATFORM.match?(/linux\-musl/)
                       '/usr/local/lib/libsqlitefunctions.so'
                     end
    load_extension_sql = <<~SQL
      -- SQRT や LOG を使いたいので
      SELECT load_extension(?);
    SQL
    db.enable_load_extension(true)
    db.execute(load_extension_sql, libsqlite_path)

    update_tfidf_column_sql = <<~SQL
      -- エントリ数をカウントしておきます
      -- SQLite には変数がないので一時テーブルにいれます
      CREATE TEMPORARY TABLE entry_total AS
          SELECT CAST(COUNT(DISTINCT entry_id) AS REAL) AS value FROM tfidf;

      -- ワード(ターム)が出てくるエントリ数を数えておきます
      -- term と entry_id でユニークなテーブルなのでこれでエントリ数になります
      CREATE TEMPORARY TABLE term_counts AS
          SELECT term, CAST(COUNT(*) AS REAL) AS cnt FROM tfidf GROUP BY term;
      CREATE INDEX temp.term_counts_term ON term_counts (term);

      -- エントリごとの合計ワード数を数えておきます
      CREATE TEMPORARY TABLE entry_term_counts AS
          SELECT entry_id, LOG(CAST(SUM(term_count) AS REAL)) AS cnt FROM tfidf GROUP BY entry_id;
      CREATE INDEX temp.entry_term_counts_entry_id ON entry_term_counts (entry_id);

      -- TF-IDF を計算して埋めます
      -- ここまでで作った一時テーブルからひいて計算しています。
      UPDATE tfidf SET tfidf = IFNULL(
          -- tf (normalized with Harman method)
          (
              LOG(CAST(term_count AS REAL) + 1) -- term_count in an entry
              /
              (SELECT cnt FROM entry_term_counts WHERE entry_term_counts.entry_id = tfidf.entry_id) -- total term count in an entry
          )
          *
          -- idf (normalized with Sparck Jones method)
          (1 + LOG(
              (SELECT value FROM entry_total) -- total
              /
              (SELECT cnt FROM term_counts WHERE term_counts.term = tfidf.term) -- term entry count
          ))
      , 0.0);
    SQL
    db.execute_batch(update_tfidf_column_sql)

    vector_normalize_sql = <<~SQL
      -- エントリごとのTF-IDFのベクトルの大きさを求めておきます
      CREATE TEMPORARY TABLE tfidf_size AS
          SELECT entry_id, SQRT(SUM(tfidf * tfidf)) AS size FROM tfidf
          GROUP BY entry_id;
      CREATE INDEX temp.tfidf_size_entry_id ON tfidf_size (entry_id);

      -- 計算済みの TF-IDF をベクトルの大きさで割って正規化します
      UPDATE tfidf SET tfidf_n = IFNULL(tfidf / (SELECT size FROM tfidf_size WHERE entry_id = tfidf.entry_id), 0.0);
    SQL
    db.execute_batch(vector_normalize_sql)
  end

  desc 'Export calculation result to MySQL'
  task :export do
    stale_ids = SimilarEntriesTask.stale_entry_ids

    create_similar_candidate_sql = <<~SQL
      DROP TABLE IF EXISTS similar_candidate;
      DROP INDEX IF EXISTS index_sc_parent_id;
      DROP INDEX IF EXISTS index_sc_entry_id;
      DROP INDEX IF EXISTS index_sc_cnt;
      CREATE TABLE similar_candidate (
        `id` INTEGER PRIMARY KEY,
        `parent_id` INTEGER NOT NULL,
        `entry_id` INTEGER NOT NULL,
        `cnt` INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX index_sc_parent_id ON similar_candidate (parent_id);
      CREATE INDEX index_sc_entry_id ON similar_candidate (entry_id);
      CREATE INDEX index_sc_cnt ON similar_candidate (cnt);
    SQL
    db.execute_batch(create_similar_candidate_sql)

    extract_similar_entries_sql = <<~SQL
      -- 類似していそうなエントリを共通語ベースでまず100エントリほど出します
      INSERT INTO similar_candidate (`parent_id`, `entry_id`, `cnt`)
          SELECT ? as parent_id, entry_id, COUNT(*) as cnt FROM tfidf
          WHERE
              entry_id <> ? AND
              term IN (
                  SELECT term FROM tfidf WHERE entry_id = ?
                  ORDER BY tfidf DESC
                  LIMIT 50
              )
          GROUP BY entry_id
          HAVING cnt > 3
          ORDER BY cnt DESC
          LIMIT 100;
    SQL

    search_similar_entries_sql = <<~SQL
      -- 該当する100件に対してスコアを計算してソートします
      SELECT
          ? AS entry_id,
          entry_id AS similar_entry_id,
          SUM(a.tfidf_n * b.tfidf_n) AS score
      FROM (
          (SELECT term, tfidf_n FROM tfidf WHERE entry_id = ? ORDER BY tfidf DESC LIMIT 50) as a
          INNER JOIN
          (SELECT entry_id, term, tfidf_n FROM tfidf WHERE entry_id IN (SELECT entry_id FROM similar_candidate WHERE parent_id = ?)) as b
          ON
          a.term = b.term
      )
      WHERE similar_entry_id <> ?
      GROUP BY entry_id
      ORDER BY score DESC
      LIMIT 10;
    SQL

    results = {}
    db.results_as_hash = true

    # stale なエントリのみ類似度を再計算
    stale_ids.each do |entry_id|
      db.execute(extract_similar_entries_sql, [entry_id, entry_id, entry_id])
      similarities = db.execute(search_similar_entries_sql, [entry_id, entry_id, entry_id, entry_id])
      results[entry_id] = similarities
      db.execute('DELETE FROM similar_candidate WHERE parent_id = ?', [entry_id])
    end

    # stale なエントリの similarities だけ差し替え（TRUNCATE しない）
    Similarity.where(entry_id: stale_ids).delete_all

    similarities = []
    results.each_value do |_similarities|
      next unless _similarities.present?
      _similarities.each do |s|
        params = { entry_id: s['entry_id'], similar_entry_id: s['similar_entry_id'], score: s['score'] }
        similarity = Similarity.new(params)
        similarities << similarity
      end
    end
    Similarity.import similarities
  end
end
