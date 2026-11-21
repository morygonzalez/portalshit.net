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

  it 'does not redirect missing API requests' do
    create(:post, slug: 'hello-world')

    get '/api/hello-worle'

    expect(last_response.status).to eq(404)
    expect(last_response.headers['Location']).to be_nil
  end
end
