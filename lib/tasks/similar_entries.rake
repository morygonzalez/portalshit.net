# frozen_string_literal: true
require 'activerecord-import'

ENV['NEWRELIC_AGENT_ENABLED'] = 'false'

class ExecutionDetector
  attr_reader :force, :message

  def initialize(arguments: {})
    @force = arguments[:force]
  end

  def run_execution?
    case
    when force.present? && force == 'true'
      @message =  'This is a force execution because the force flag is set true.'
      true
    when Similarity.count.zero?
      @message = 'Run execution because there is no similarity records.'
      true
    when latest_entry_with_similarity == latest_published_entry
      @message = 'Skip similarity detection because the latest entry already has similar entries'
      false
    else
      @message = 'Updating simimarity...'
      true
    end
  end

  private

  def latest_updated_at
    @latest_updated_at = Similarity.joins(:entry).maximum(:'entries.updated_at')
  end

  def latest_entry_with_similarity
    @latest_entry_with_similarity = Entry.find_by(updated_at: latest_updated_at)
  end

  def latest_published_entry
    @latest_published_entry = Entry.published.order(updated_at: :desc).first
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

    entries = Entry.includes(:category, :tags).published
    entry_frequencies = {}
    entries.each do |entry|
      text_to_tokenize = <<~HEREDOC.strip_heredoc
        #{entry.title}
        #{entry.raw_body})
        #{entry.category&.title}
        #{entry.tag_list.join(' ')}
      HEREDOC
      words = Tokenizer.run(text_to_tokenize)
      frequency = words.each_with_object(Hash.new(0)) {|word, sum| sum[word] += 1; }
      entry_frequencies[entry.id] = frequency
    end
    entry_frequencies.each do |entry_id, frequency|
      frequency.each do |word, count|
        db.execute('INSERT INTO tfidf (`term`, `entry_id`, `term_count`) VALUES (?, ?, ?)', [word, entry_id, count])
      end
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
    Entry.published.pluck(:id).each do |entry_id|
      db.execute(extract_similar_entries_sql, [entry_id, entry_id, entry_id])
      db.results_as_hash = true
      similarities = db.execute(search_similar_entries_sql, [entry_id, entry_id, entry_id, entry_id])
      results[entry_id] = similarities
    end

    Similarity.connection.execute('TRUNCATE table similarities;')

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
