# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Missing article redirects' do
  include_context 'in site'
  before { Site.first.update!(theme: 'portalshit') }

  it 'redirects temporarily to the single published slug suggestion' do
    post = create(:post, slug: 'hello-world')
    create(:post, slug: 'hello-worlds', draft: true)

    get '/hello-worle'

    expect(last_response.status).to eq(302)
    expect(URI.parse(last_response.location).path).to eq(post.link)
  end

  it 'returns 404 when there are multiple suggestions' do
    create(:post, slug: 'hello-world')
    create(:post, slug: 'hello-worlds')

    get '/hello-worle'

    expect(last_response.status).to eq(404)
  end

  it 'returns 404 when there is no suggestion' do
    create(:post, slug: 'hello-world')

    get '/unrelated-path'

    expect(last_response.status).to eq(404)
  end

  it 'suggests an article for a mistyped slug in the configured permalink' do
    Option.permalink_enabled = 'true'
    Option.permalink_format = '/%year%/%monthnum%/%day%/%slug%'
    post = create(:post, slug: 'hello-world')

    get post.link.sub('hello-world', 'hello-worle')

    expect(last_response.status).to eq(302)
    expect(URI.parse(last_response.location).path).to eq(post.link)
  end

  it 'serves the static 404 for non-article paths without looking up a suggestion' do
    create(:post, slug: 'hello-world')
    Option.permalink_enabled = 'true'
    Option.permalink_format = '/%year%/%monthnum%/%day%/%slug%'
    static_page = File.binread(File.join(Lokka::App.public_folder, '404.html'))

    expect(DidYouMean::SpellChecker).not_to receive(:new)
    [
      '/config/hello-worle',
      '/storage/framework/sessions/hello-worle',
      '/hello-worle.json',
      '/2011/01/09/hello-worle.json'
    ].each do |path|
      get path

      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to eq('text/html;charset=utf-8')
      expect(last_response.body.b).to eq(static_page)
    end

    head '/hello-worle.json'
    expect(last_response.status).to eq(404)
    expect(last_response.body).to be_empty
  end

  it 'does not redirect missing API requests' do
    create(:post, slug: 'hello-world')

    get '/api/hello-worle'

    expect(last_response.status).to eq(404)
    expect(last_response.headers['Location']).to be_nil
  end
end
