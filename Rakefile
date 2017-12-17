require './init'
require 'yard'
include Rake::DSL if defined? Rake::DSL

task :default => ['spec:setup', 'db:delete', :spec]

desc 'Migrate the Lokka database'
task 'db:migrate' do
  puts 'Upgrading Database...'
  Lokka::Database.new.connect.migrate
end

desc 'Execute seed script'
task 'db:seed' do
  puts 'Initializing Database...'
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.logger.set_log STDERR, :debug, "SQL: ", true
  Lokka::Database.new.connect.seed
end

desc 'Delete database'
task 'db:delete' do
  puts 'Delete Database...'
  Lokka::Database.new.connect.migrate!
end

desc 'Reset database'
task 'db:reset' => %w(db:delete db:seed)

desc 'Set up database'
task 'db:setup' => %w(db:migrate db:seed)

desc 'Install gems'
task :bundle do
  `bundle install --path vendor/bundle --without production test`
end

desc 'Install'
task :install => %w(bundle db:setup)

desc 'Generate documentation for Lokka'
task :doc do
  YARD::CLI::Yardoc.new.run
end

desc 'set ENV'
task 'spec:setup' do
  ENV['RACK_ENV'] = ENV['LOKKA_ENV'] = 'test'
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec => 'spec:setup') do |spec|
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rspec_opts = ['-cfs']
  end
rescue LoadError => e
end

desc "export ids and bodies of entries"
task :export_entries do
  require 'natto'
  require 'sqlite3'
  require 'parallel'

  nm = Natto::MeCab.new
  db = SQLite3::Database.new('db/tfidf.sqlite3')
  sql =<<~SQL
    -- DROP TABLE IF EXISTS tfidf;
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
  db.execute(sql)

  entries = Entry.all(fields: [:id, :body])
  entry_word_frequencies = {}
  Parallel.each(entries, in_threads: 10) do |entry|
    words = []
    body_cleansed = entry.body.
      gsub(/<.+?>/, '').
      gsub(/!?\[.+?\)/, '').
      gsub(/(```|<code>).+?(```|<\/code>)/m, '')
    nm.parse(body_cleansed) do |n|
      next if !n.feature.match(/名詞/)
      next if n.feature.match(/(サ変接続|数)/)
      next if n.surface.match(/\A([:ascii:]|[:alnum:]|\p{hiragana}|\p{katakana})\Z/i)
      next if  %w[これ こと とき よう そう やつ ところ 用 lt gt ここ なか どこ まま わけ ため 的 それ あと].include?(n.surface)
      words << n.surface
    end
    frequency = words.inject(Hash.new(0)) {|sum, word|
      sum[word] += 1; sum
    }.sort_by {|item|
      item.to_a[1]
    }.reverse.to_h
    entry_word_frequencies[entry.id] = frequency
  end
  Parallel.each(entry_word_frequencies, in_threads: 10) do |entry_id, frequency|
    frequency.each do |word, count|
      db.execute("INSERT INTO tfidf (`term`, `entry_id`, `term_count`) VALUES (?, ?, ?)", [word, entry_id, count])
    end
  end
end
