# frozen_string_literal: true

desc 'Detect and update similar entries'
task similar_entries: %i[similar_entries:extract_term similar_entries:vector_normalize similar_entries:export]

namespace :similar_entries do
  def db
    @db ||= begin
              require 'sqlite3'
              SQLite3::Database.new(':memory:')
            end
  end

  def target_entry_exists?
    Entry.last.id > Similarity.maximum(:entry_id)
  end

  desc 'Extract term'
  task :extract_term do
    next unless target_entry_exists?

    require 'natto'
    nm = Natto::MeCab.new
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

    entries = Entry.published.all(fields: %i[id body])
    entry_frequencies = {}
    entries.each do |entry|
      words = []
      body_cleansed = entry.title + entry.tags.map(&:name).join(' ') +
        entry.raw_body.
          gsub(/<.+?>/, '').
          gsub(/!?\[.+?\)/, '').
          gsub(%r{(?:```|<code>)(.+?)(?:```|</code>)}m, '\1')
      begin
        words_to_ignore = %w[
          これ こと とき よう そう やつ とこ ところ 用 もの はず みたい たち いま 後 確か 中 気 方
          頃 上 先 点 前 一 内 lt gt ここ なか どこ まま わけ ため 的 それ あと
        ]
        nm.parse(body_cleansed) do |n|
          next unless n.feature.match?(/名詞/)
          next if n.feature.match?(/(サ変接続|数)/)
          next if n.surface.match?(/\A([a-z][0-9]|\p{hiragana}|\p{katakana})\Z/i)
          next if words_to_ignore.include?(n.surface)
          words << n.surface
        end
      rescue ArgumentError
        next
      end
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
    next unless target_entry_exists?

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
    next unless target_entry_exists?

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
    Entry.published.pluck(:id).each do |entry|
      db.execute(extract_similar_entries_sql, [entry.id, entry.id, entry.id])
      db.results_as_hash = true
      similarities = db.execute(search_similar_entries_sql, [entry.id, entry.id, entry.id, entry.id])
      results[entry.id] = similarities
    end

    Similarity.delete_all

    results.each_value do |similarities|
      next unless similarities.present?
      similarities.each do |s|
        conditions = { entry_id: s['entry_id'], similar_entry_id: s['similar_entry_id'] }
        similarity = Similarity.find_or_initialize_by(conditions)
        similarity.score = s['score']
        similarity.save
      end
    end
  end
end
