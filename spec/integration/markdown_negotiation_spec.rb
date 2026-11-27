# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Markdown content negotiation' do
  include_context 'in site'

  let!(:article) do
    create(:post_with_slug, title: '記事タイトル', body: <<~HTML)
      <h2>本文の見出し</h2>
      <p><a href="/archives">Archives</a></p>
      <ul><li>リスト項目</li></ul>
      <pre><code>puts 42</code></pre>
      <script>script_content()</script>
    HTML
  end

  it 'serves Markdown from the article URL and keeps the content structure' do
    get article.link, {}, 'HTTP_ACCEPT' => 'text/markdown, text/html;q=0.5'

    expect(last_response).to be_ok
    expect(last_response.content_type).to eq('text/markdown;charset=utf-8')
    expect(last_response.headers['vary']).to include('Accept')
    expect(last_response.body).to include(
      '# 記事タイトル', '## 本文の見出し', '[Archives](/archives)',
      'リスト項目', "```\nputs 42\n```"
    )
    expect(last_response.body).not_to include('script_content', '<h2>')
  end

  it 'keeps HTML as the default and honors explicit HTML preference and Markdown rejection' do
    [nil, '*/*', 'text/markdown;q=0', 'text/html, text/markdown;q=0.5'].each do |accept|
      get article.link, {}, accept ? { 'HTTP_ACCEPT' => accept } : {}

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/html')
      expect(last_response.headers['vary']).to include('Accept')
    end
  end

  it 'lists published entries on the home and archive pages' do
    create(:post, title: '未公開記事', draft: true)

    ['/', '/2011/', '/2011/01/'].each do |path|
      get path, {}, 'HTTP_ACCEPT' => 'text/markdown'

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/markdown')
      expect(last_response.body).to include("[#{article.title}](#{article.link})")
      expect(last_response.body).not_to include('未公開記事')
    end

    get '/', {}, 'HTTP_ACCEPT' => 'text/markdown'
    expect(last_response.body).to match(/\]\(\/popular\)/)
    expect(last_response.body).to match(/\]\(\/archives\)/)

    get '/archives', {}, 'HTTP_ACCEPT' => 'text/markdown'
    expect(last_response.content_type).to start_with('text/markdown')
    expect(last_response.body).to include('[2011](/archives/2011)')

    get '/archives/2011', {}, 'HTTP_ACCEPT' => 'text/markdown'
    expect(last_response.content_type).to start_with('text/markdown')
    expect(last_response.body).to include('[2011/01](/2011/01/)')
  end

  it 'serves fixed pages and custom article permalinks' do
    page = create(:page, title: '固定ページ')
    Option.permalink_enabled = 'true'
    Option.permalink_format = '/%year%/%monthnum%/%day%/%slug%'

    [[page.link, page.title], [article.link, article.title]].each do |path, title|
      get path, {}, 'HTTP_ACCEPT' => 'text/markdown'

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/markdown')
      expect(last_response.body).to include("# #{title}")
    end
  end

  it 'serves category and tag listings with pagination links' do
    category = create(:category)
    article.update!(category: category, tag_collection: 'testtag')
    create(:post, category: category, tag_collection: 'testtag', created_at: article.created_at - 1.day)
    Site.first.update!(per_page: 1)

    [category.link, '/tags/testtag'].each do |path|
      get path, {}, 'HTTP_ACCEPT' => 'text/markdown'

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/markdown')
      expect(last_response.body).to include("[#{article.title}](#{article.link})", 'page=2')
    end
  end

  it 'serves the popular rankings as Markdown and defaults to HTML' do
    ranking = Post.includes(:category, :tags)
    allow(Post).to receive(:includes).and_call_original
    allow(Post).to receive(:includes).with(:category, :tags).and_return(ranking)
    allow(ranking).to receive(:popular).with(target: 'today', limit: 4).and_return([article])
    allow(ranking).to receive(:popular).with(target: 'yesterday', limit: 4).and_return([])
    allow(ranking).to receive(:popular).with(target: 'all', limit: 4).and_return([])
    allow(ranking).to receive(:hotentry).with(limit: 4).and_return([])
    allow(ranking).to receive(:popular).with(target: 'all', limit: 25).and_return([article])
    allow(ranking).to receive(:hotentry).with(limit: 25).and_return([article])

    get '/popular', {}, 'HTTP_ACCEPT' => 'text/markdown'

    expect(last_response).to be_ok
    expect(last_response.content_type).to start_with('text/markdown')
    expect(last_response.headers['vary']).to include('Accept')
    expect(last_response.body.scan(/^## /).size).to eq(4)
    expect(last_response.body).to include("[#{article.title}](#{article.link})")
    expect(last_response.body).to include('](/popular/recent)', '](/popular/hatena-bookmark)')

    get '/popular'

    expect(last_response).to be_ok
    expect(last_response.content_type).to start_with('text/html')
    expect(last_response.headers['vary']).to include('Accept')

    %w[/popular/recent /popular/hatena-bookmark].each do |path|
      get path, {}, 'HTTP_ACCEPT' => 'text/markdown'

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/markdown')
      expect(last_response.headers['vary']).to include('Accept')
      expect(last_response.body).to include("[#{article.title}](#{article.link})")

      get path

      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with('text/html')
      expect(last_response.headers['vary']).to include('Accept')
    end
  end

  it 'reports the Markdown content type for HEAD without a body' do
    head article.link, {}, 'HTTP_ACCEPT' => 'text/markdown'

    expect(last_response).to be_ok
    expect(last_response.content_type).to start_with('text/markdown')
    expect(last_response.body).to be_empty
  end

  it 'preserves the Atom representation' do
    get '/index.atom', {}, 'HTTP_ACCEPT' => 'text/markdown'

    expect(last_response).to be_ok
    expect(last_response.content_type).to start_with('application/atom+xml')
  end

  it 'sets the shared cache policy only on the public canonical Atom representation' do
    get '/index.atom'
    expect(last_response.headers['cache-control']).to eq('public, max-age=0, s-maxage=3600')

    get '/index.atom?page=1'
    expect(last_response).to be_ok
    expect(last_response.headers['cache-control']).to eq('private, no-store')

    get '/index.atom', {}, 'HTTP_AUTHORIZATION' => 'Basic dGVzdDp0ZXN0'
    expect(last_response.headers['cache-control']).to eq('private, no-store')

    get '/index.atom', {}, 'HTTP_COOKIE' => 'example=value'
    expect(last_response.headers['cache-control']).to eq('private, no-store')

    get article.link
    expect(last_response.headers['cache-control'].to_s).not_to include('s-maxage=3600')
  end

  it 'serves an empty Atom feed after the last published post is removed' do
    article.destroy!
    get '/index.atom'

    expect(last_response).to be_ok
    expect(last_response.body).to include('<feed', '<updated>')
    expect(last_response.body).not_to include('<entry>')
  end

  it 'returns an Atom body only when the feed has changed for a conditional GET' do
    get '/index.atom'

    expect(last_response).to be_ok
    original_etag = last_response.headers['etag']
    expect(original_etag).to match(/\AW\/"[0-9a-f]{64}"\z/)

    clear_cookies
    get '/index.atom', {}, 'HTTP_IF_NONE_MATCH' => original_etag

    expect(last_response.status).to eq(304)
    expect(last_response.headers['cache-control']).to eq('public, max-age=0, s-maxage=3600')
    expect(last_response.body).to be_empty

    article.update!(body: '<p>Updated Atom content</p>')
    clear_cookies
    get '/index.atom', {}, 'HTTP_IF_NONE_MATCH' => original_etag

    expect(last_response).to be_ok
    expect(last_response.headers['etag']).not_to eq(original_etag)
    expect(last_response.body).to include('Updated Atom content')
  end
end
