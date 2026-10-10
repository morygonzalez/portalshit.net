# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'fileutils'
require 'rspec'

describe 'Article access ranking' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:aggregator) { File.join(root, 'bin/lib/access_ranking.awk') }
  let(:article) { '/2026/10/03/ai-is-eating-product-management' }

  def aggregate(input, format = 'ltsv')
    output, error, status = Open3.capture3(
      'awk', '-v', "input_format=#{format}", '-f', aggregator, stdin_data: input
    )
    expect(status.success?).to eq(true), error
    output.lines.to_h do |line|
      count, path = line.split
      [path, count.to_i]
    end
  end

  def logs(paths)
    paths.map { |path| "time:2026-10-10\tstatus:200\trequest_uri:#{path}\n" }.join
  end

  it 'merges article queries while preserving numeric and percent-encoded slugs' do
    paths = [article, "#{article}?fbclid=abc", "#{article}?comment_submitted=1",
             '/2007/02/09/747', '/2026/10/03/a%3Fb']
    expect(aggregate(logs(paths))).to eq(
      article => 3, '/2007/02/09/747' => 1, '/2026/10/03/a%3Fb' => 1
    )
  end

  it 'excludes search, index, archives, categories, tags and non-article pages' do
    paths = ['/', '/?page=2', '/search/', '/search/?query=Ruby', '/search',
             '/2026/', '/2026/10/', '/2026/10/03/', '/archives', '/categories',
             '/category/ruby', '/tags/Ruby', '/popular', '/about', '/api/posts',
             '/theme/portalshit/style.css', '/2026/10/03/slug/edit', '-']
    expect(aggregate(logs(paths + [article]))).to eq(article => 1)
  end

  it 'does not reuse the previous URI on empty or malformed log lines' do
    input = logs([article]) + "\ntime:2026-10-10\tstatus:200\n"
    expect(aggregate(input)).to eq(article => 1)
  end

  it 'uses the same rules for legacy path input' do
    input = [article, "#{article}?utm_source=test", '/search/?query=test', '/2026/'].join("\n")
    expect(aggregate(input, 'paths')).to eq(article => 2)
  end

  it 'sums GA view counts instead of counting GA rows' do
    input = "89 #{article}\n22 #{article}?fbclid=abc\n700 /search/\n\n" \
            "  4 /2007/02/09/747\ninvalid #{article}\n"
    expect(aggregate(input, 'ranking')).to eq(article => 111, '/2007/02/09/747' => 4)
  end

  it 'filters and merges before selecting the daily top 100' do
    Dir.mktmpdir('article-access-ranking') do |directory|
      FileUtils.mkdir_p(File.join(directory, 'lib'))
      FileUtils.cp(File.join(root, 'bin/access_ranking'), directory)
      FileUtils.cp(aggregator, File.join(directory, 'lib/access_ranking.awk'))
      File.write(File.join(directory, 'lib/common.sh'), <<~SHELL)
        LOG_AGGREGATION_DIR="#{directory}"
        filter_logs() { cat "#{directory}/logs"; }
      SHELL
      other_articles = (1..105).map { |i| "/2026/10/03/article-#{i}" }
      queries = (1..250).map { |i| "#{article}?tracking=#{i}" }
      File.write(File.join(directory, 'logs'), logs(['/search/'] * 300 + queries + other_articles))
      _output, error, status = Open3.capture3('bash', File.join(directory, 'access_ranking'), 'today')
      expect(status.success?).to eq(true), error
      ranking = File.readlines(File.join(directory, 'access-ranking-today.txt'))
      expect(ranking.size).to eq(100)
      expect(ranking.first).to eq("250 #{article}\n")
      expect(ranking.grep(%r{/search/})).to be_empty
    end
  end
end
