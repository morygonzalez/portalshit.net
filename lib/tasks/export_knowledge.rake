# frozen_string_literal: true

begin
  require 'dotenv/load' # 任意（.env 読み込み）
rescue LoadError
end

require 'json'
require 'cgi'
require 'net/http'
require 'uri'
require 'set'
require 'nokogiri'
require 'csv'
require 'fileutils'

# =========================
# 設定（ENV）
# =========================
DIFY_API_BASE      = ENV.fetch('DIFY_API_BASE', 'https://api.dify.ai')
DIFY_DATASET_ID    = ENV['DATASET_ID']          # 必須（アップロード/修復時）
DIFY_DATASET_TOKEN = ENV['DATASET_API_KEY']     # 必須（アップロード/修復時）
BASE_URL           = (ENV['BASE_URL'] || '').sub(%r{/\z}, '')

DEFAULT_SLEEP_SECS = (ENV['SLEEP_SECS'] || '7').to_f
DEFAULT_RETRIES    = (ENV['RETRIES']    || '6').to_i
STATE_FILE         = ENV['STATE_FILE']  || '.dify_uploaded_names'

# =========================
# HTTP helpers
# =========================
def http_get(path, query = {})
  raise 'ENV[DATASET_API_KEY] not set' unless DIFY_DATASET_TOKEN
  uri = URI.join(DIFY_API_BASE, path)
  uri.query = URI.encode_www_form(query) unless query.empty?
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{DIFY_DATASET_TOKEN}"
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
end

def http_post_json(path, body_hash)
  raise 'ENV[DATASET_API_KEY] not set' unless DIFY_DATASET_TOKEN
  uri = URI.join(DIFY_API_BASE, path)
  req = Net::HTTP::Post.new(uri)
  req['Authorization'] = "Bearer #{DIFY_DATASET_TOKEN}"
  req['Content-Type']  = 'application/json'
  req.body = JSON.dump(body_hash)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
end

def with_retry(retries)
  tries = 0
  begin
    yield
  rescue => e
    tries += 1
    raise e if tries > retries
    backoff = (2**tries) * 0.5 # 0.5,1,2,4,8,...
    warn "retry(#{tries}) after #{backoff}s: #{e.class} #{e.message}"
    sleep backoff
    retry
  end
end

# =========================
# テキスト整形
# =========================
def safe_join_url(base, maybe_path)
  return nil if base.to_s.empty? && maybe_path.to_s.empty?
  path = maybe_path.to_s
  if path.start_with?('http://', 'https://')
    path
  else
    base = base.to_s.sub(%r{/\z}, '')
    path = "/#{path}" unless path.start_with?('/')
    base.empty? ? path : "#{base}#{path}"
  end
end

def extract_plain_text_from_html(html_src)
  html = html_src.to_s
  html = html.gsub(/<\s*br\s*\/?>/i, "\n").gsub(/\u00A0/, ' ')
  doc  = Nokogiri::HTML::DocumentFragment.parse(html)
  text = doc.xpath('.//text()').map(&:text).join
  text = CGI.unescapeHTML(text)
  text = text.gsub(/\r\n?/, "\n").strip
  text = text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  text = text.gsub(/[^\P{Cntrl}\t\n]/, '')
  text
end

def build_url_for(post)
  candidate =
    if post.respond_to?(:link) && post.link
      post.link.to_s
    elsif post.respond_to?(:slug) && post.slug
      "/#{post.slug}"
    else
      "/posts/#{post.id}"
    end
  safe_join_url(BASE_URL, candidate)
end

def article_hash(post)
  html = (post.respond_to?(:raw_body) ? post.raw_body : post.respond_to?(:body) ? post.body.to_s : '')
  text = extract_plain_text_from_html(html)
  tags = post.respond_to?(:tags) ? Array(post.tags).map { |t| t.respond_to?(:name) ? t.name : t.to_s } : []
  {
    id:      post.respond_to?(:id) ? post.id : nil,
    title:   post.respond_to?(:title) ? post.title.to_s : '',
    date:    (post.respond_to?(:created_at) ? post.created_at&.to_date&.to_s : nil),
    tags:    tags,
    slug:    (post.respond_to?(:slug) && post.slug ? post.slug.to_s : nil),
    url:     build_url_for(post),
    source:  'portalshit.net',
    content: text
  }
end

def compose_article_block(h)
  <<~TXT
  [published_at: #{h[:date]}]
  Title: #{h[:title]}
  URL: #{h[:url]}

  #{h[:content]}

  ---
  TXT
end

def compose_year_text(posts_for_year)
  posts_for_year.map { |h| compose_article_block(h) }.join("\n")
end

# =========================
# Dify Document ops
# =========================
def create_by_text!(name:, text:, date: nil, url: nil)
  raise 'ENV[DATASET_ID] not set' unless DIFY_DATASET_ID
  res  = http_post_json("/v1/datasets/#{DIFY_DATASET_ID}/document/create-by-text", {
    name: name,
    text: text,
    indexing_technique: 'high_quality',
    process_rule: { mode: 'automatic' }
  })
  body = JSON.parse(res.body) rescue {}
  unless res.is_a?(Net::HTTPSuccess) && body.dig('document','id')
    raise "create-by-text failed #{res.code} #{res.body}"
  end
  body.dig('document','id')
end

def update_by_text!(document_id:, name:, text:)
  res = http_post_json("/v1/datasets/#{DIFY_DATASET_ID}/documents/#{document_id}/update_by_text", {
    name: name,
    text: text
  })
  body = JSON.parse(res.body) rescue {}
  unless res.is_a?(Net::HTTPSuccess) && body.dig('document', 'id')
    raise "update_by_text failed #{res.code} #{res.body}"
  end
  body.dig('document','id')
end

# pairs: [{ document_id: "uuid", metadata: { "period"=>"2005", "count"=>145, ... } }, ...]
def update_documents_metadata!(pairs)
  return if pairs.nil? || pairs.empty?

  # name -> id を取得
  name2id = fetch_metadata_field_ids

  # name を id に変換（見つからなければスキップ or 環境変数で補完）
  # 環境変数で直指定もサポート（例: METADATA_ID_PERIOD=uuid）
  env_overrides = {
    "period"       => ENV['METADATA_ID_PERIOD'],
    "count"        => ENV['METADATA_ID_COUNT']
  }.compact

  op = {
    operation_data: pairs.map do |p|
      meta_ids = p.fetch(:metadata).filter_map do |k, v|
        fid = env_overrides[k.to_s] || name2id[k.to_s]
        if fid.nil? || fid.empty?
          warn "[metadata] skip key=#{k} (field id not found)"
          nil
        else
          { id: fid, value: v }
        end
      end
      {
        document_id:  p.fetch(:document_id),
        metadata_list: meta_ids
      }
    end
  }

  # 送る前に一度確認したければ↓を一時的に有効化
  # puts JSON.pretty_generate(op)

  res  = http_post_json("/v1/datasets/#{DIFY_DATASET_ID}/documents/metadata", op)
  code = res.code.to_i
  raise "metadata update failed #{res.code} #{res.body}" unless code == 202 || code == 200
  res
end

def list_all_documents(dataset_id:, page_size: 100)
  docs = []
  page = 1
  loop do
    res  = http_get("/v1/datasets/#{dataset_id}/documents", { page: page, limit: page_size })
    body = JSON.parse(res.body) rescue {}
    raise "list documents failed #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess) && body['data'].is_a?(Array)
    docs.concat(body['data'])
    total = body['total'] || docs.size
    break if docs.size >= total || body['data'].empty?
    page += 1
  end
  docs
end

def build_name_to_docid_map
  docs = list_all_documents(dataset_id: DIFY_DATASET_ID)
  docs.each_with_object({}) { |d, m| m[d['name'].to_s] = d['id'] }
end

# データセットのメタデータ定義を取得して { name => id } を返す
def fetch_metadata_field_ids
  # 候補エンドポイントを順に試す（環境差対応）
  candidates = [
    "/v1/datasets/#{DIFY_DATASET_ID}/metadata/fields",
    "/v1/datasets/#{DIFY_DATASET_ID}/metadata",          # 環境によってはこちら
    "/v1/datasets/#{DIFY_DATASET_ID}/doc_metadata/fields"
  ]
  last_err = nil
  candidates.each do |path|
    begin
      res = http_get(path)
      body = JSON.parse(res.body) rescue {}
      # だいたい data 配下、または fields 配下に [ {id,name,...}, ... ]
      list = body['data'] || body['fields'] || body
      if res.is_a?(Net::HTTPSuccess) && list.is_a?(Array)
        return list.each_with_object({}) { |f, m| m[f['name']] = f['id'] if f['name'] && f['id'] }
      end
      last_err = "#{res.code} #{res.body}"
    rescue => e
      last_err = e.message
    end
  end
  warn "[metadata] could not fetch field IDs automatically: #{last_err}"
  {}
end

# =========================
# Rake tasks（:environment 依存なし）
# =========================
namespace :knowledge do
  desc 'Export posts (out_path[, format=jsonl|csv|txt])'
  task :export, [:out_path, :format] do |_, args|
    out_path = args[:out_path] || 'tmp/knowledge_posts.jsonl'
    format   = (args[:format] || File.extname(out_path).sub('.', '')).downcase
    FileUtils.mkdir_p(File.dirname(out_path))

    rows = []
    # ★ ここはあなたのアプリの取込元に合わせて書き換え：
    #   Entry.published が無い場合は独自の列挙に置換してください。
    Entry.published.includes(:tags, :category).each do |post|
      rows << article_hash(post)
    rescue => e
      warn "[export] skip id=#{post.respond_to?(:id) ? post.id : 'n/a'}: #{e.class} #{e.message}"
    end

    case format
    when 'jsonl', ''
      File.open(out_path, 'w:utf-8') { |f| rows.each { |h| f.puts(JSON.dump(h)) } }
    when 'csv'
      CSV.open(out_path, 'w', headers: true, write_headers: true, encoding: 'UTF-8') do |csv|
        csv << %w[id title date tags slug url content]
        rows.each { |h| csv << [h[:id], h[:title], h[:date], Array(h[:tags]).join(' '), h[:slug], h[:url], h[:content]] }
      end
    when 'txt'
      File.open(out_path, 'w:utf-8') { |f| rows.each { |h| f.write(compose_article_block(h)) } }
    else
      abort "[export] unsupported format: #{format}"
    end

    puts "[export] done: #{rows.size} records -> #{out_path}"
  end

  desc 'Upload posts grouped by year (one document per year)'
  task :upload_yearly, [:sleep_secs, :retries] do |_, args|
    abort '[upload_yearly] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless DIFY_DATASET_ID && DIFY_DATASET_TOKEN
    sleep_secs = (args[:sleep_secs] || DEFAULT_SLEEP_SECS).to_f
    retries    = (args[:retries]    || DEFAULT_RETRIES).to_i

    rows = []
    Entry.published.includes(:tags, :category).each do |post|
      rows << article_hash(post)
    rescue => e
      warn "[upload_yearly] skip id=#{post.respond_to?(:id) ? post.id : 'n/a'}: #{e.class} #{e.message}"
    end

    groups = rows.group_by { |h| (h[:date] || '').slice(0, 4) || 'unknown' }

    done = File.exist?(STATE_FILE) ? File.readlines(STATE_FILE, chomp: true).to_set : Set.new
    File.open(STATE_FILE, 'a') do |state|
      batch = []  # ← ここで初期化（NameError対策）
      groups.sort.each do |year, items|
        name = year
        if done.include?(name)
          puts "[upload_yearly] skip (done): #{name}"
          next
        end

        text = compose_year_text(items)
        with_retry(retries) do
          doc_id = create_by_text!(name: name, text: text, date: "#{year}-01-01", url: nil)
          # 年次メタは period/count を付与
          batch << { document_id: doc_id, metadata: { 'period' => year, 'count' => items.size } }
          puts "[upload_yearly] ok #{name} (#{doc_id}) items=#{items.size}"
        end

        state.puts(name); state.flush
        sleep sleep_secs

        if batch.size >= 10
          update_documents_metadata!(batch)
          batch.clear
          sleep sleep_secs
        end
      rescue Interrupt
        warn "[upload_yearly] interrupted by user"; raise
      rescue => e
        warn "[upload_yearly] skip #{name}: #{e.class} #{e.message}"
      end

      update_documents_metadata!(batch) unless batch.empty?
    end

    puts "[upload_yearly] done. state: #{STATE_FILE}"
  end

  desc 'Repair metadata (re-apply period/count by listing documents)'
  task :repair_year_metadata, [:batch_size] do |_, args|
    abort '[repair_year_metadata] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless DIFY_DATASET_ID && DIFY_DATASET_TOKEN
    batch_size = (args[:batch_size] || 20).to_i

    name2id = build_name_to_docid_map

    counts = Hash.new(0)
    Entry.published.includes(:tags, :category).each do |post|
      y = (post.respond_to?(:created_at) ? post.created_at&.year : nil)
      next unless y
      y = y.to_s
      counts[y] += 1 if y.match?(/\A\d{4}\z/)
    end

    missing = counts.keys.reject { |y| name2id.key?(y) }.sort
    warn "[repair] WARNING: not found for years: #{missing.join(', ')}" unless missing.empty?

    payloads = counts.sort.filter_map do |(year, cnt)|
      doc_id = name2id[year]
      next unless doc_id
      { document_id: doc_id, metadata: { 'period' => year, 'count' => cnt } }
    end

    if payloads.empty?
      puts "[repair] nothing to update"; next
    end

    payloads.each_slice(batch_size) do |slice|
      res = update_documents_metadata!(slice)
      puts "[repair] updated #{slice.size} docs (status=#{res.code})"
      sleep 1.0
    end

    puts "[repair] done."
  end

  desc 'Export then upload yearly (out_path, format=jsonl|csv|txt, sleep_secs, retries)'
  task :export_and_upload_yearly, [:out_path, :format, :sleep_secs, :retries] do |_, args|
    Rake::Task['knowledge:export'].invoke(args[:out_path], args[:format])
    Rake::Task['knowledge:upload_yearly'].invoke(args[:sleep_secs], args[:retries])
  end

  # 年指定で1件だけ更新（本文置換＋メタ再付与）
  # 使い方:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake "knowledge:update_year[2025,1.2,6]"
  desc '年指定で1件だけドキュメントを更新'
  task :update_year, [:year, :sleep_secs, :retries] do |_, args|
    abort '[update_year] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless DIFY_DATASET_ID && DIFY_DATASET_TOKEN

    year       = (args[:year] || Time.now.year.to_s).to_s
    sleep_secs = (args[:sleep_secs] || DEFAULT_SLEEP_SECS).to_f
    retries    = (args[:retries]    || DEFAULT_RETRIES).to_i

    # 1) 「年 → doc_id」マップ（name を "YYYY" で作っている前提）
    name2id = build_name_to_docid_map
    doc_id  = name2id[year]
    abort "[update_year] document not found for year=#{year} (name must be exactly '#{year}')" unless doc_id

    # 2) その年の記事をDBから再収集
    rows = []

    Entry.published.includes(:tags, :category).each do |post|
      h = article_hash(post)
      next unless (h[:date] || '').start_with?(year)
      rows << h
    rescue => e
      warn "[update_year] skip id=#{post.respond_to?(:id) ? post.id : 'n/a'}: #{e.class} #{e.message}"
    end

    if rows.empty?
      warn "[update_year] no posts found for year=#{year}; only metadata will be touched (count=0)"
    end

    # 3) 年次テキストを再生成
    new_text = compose_year_text(rows)

    # 4) 本文置換（update_by_text）をリトライ付きで
    with_retry(retries) do
      update_by_text!(document_id: doc_id, name: year, text: new_text)
      puts "[update_year] updated body for #{year} (#{doc_id}) items=#{rows.size}"
    end

    # 5) メタデータ(period/count) を operation_data（ID指定）で再付与
    payload = [{ document_id: doc_id, metadata: { 'period' => year, 'count' => rows.size } }]
    with_retry(retries) do
      update_documents_metadata!(payload)
      puts "[update_year] updated metadata for #{year} (#{doc_id})"
    end

    sleep sleep_secs
    puts "[update_year] done."
  end

  desc 'Export popular entry'
  task :popular do
    entries = Entry.popular(limit: 20)
    text = <<~ERUBY
      [period: recent_30d] [last_updated_at: <%= Date.today %>]

      # Popular Entries (last 30 days)
      <% entries.each.with_index(1) do |entry, i| %>
        <%= i %>. <%= entry.title %> - <%= build_url_for(entry) %>
          published_at: <%= entry.created_at %>
          blurb: <%= entry.summary %>
          page_views: <%= entry.pv %>
      <% end %>
    ERUBY
    erb = ERB.new(text)
    result = erb.result(binding)
    puts result
  end
end
