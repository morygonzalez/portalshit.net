# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Manual redirects' do
  include_context 'in site'

  before { Site.first.update!(theme: 'portalshit') }
  after { Option.where(name: Lokka::ManualRedirects::OPTION_NAME).delete_all }

  def save_rules(*pairs)
    rows = pairs.each_with_index.to_h { |(from, to), index| [index.to_s, { from: from, to: to }] }
    put '/admin/redirects', redirects: rows
  end

  it 'requires login to change redirects' do
    save_rules(['/old', '/new'])
    expect(Option.manual_redirects).to be_nil
  end

  context 'when logged in' do
    before do
      create(:user, name: 'test')
      post '/admin/login', name: 'test', password: 'test'
    end

    it 'adds, edits and deletes a redirect' do
      create(:post, slug: 'hello-world')
      save_rules(['/hello-worle', '/new'], ['/hello-world', '/other'])
      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_response.body).to include('/hello-worle')

      get '/hello-worle?ref=x&ref=y'
      expect(last_response.status).to eq(302)
      location = URI.parse(last_response.location)
      expect([location.path, location.query]).to eq(['/new', 'ref=x&ref=y'])

      get '/hello-world'
      expect(last_response.status).to eq(200)

      save_rules(['/hello-worle', '/updated'])
      head '/hello-worle'
      expect(URI.parse(last_response.location).path).to eq('/updated')

      save_rules(['', ''])
      get '/hello-worle'
      expect(URI.parse(last_response.location).path).to eq('/hello-world')
    end

    it 'rejects invalid edits without replacing the saved rules' do
      save_rules(['/old', '/new'])
      [
        [['/old', '//other.example']],
        [['/old', '/one'], ['/old', '/two']],
        [['/old', '/old']],
        [['/old', '/two'], ['/two', '/old']],
        [['/old', '/two/'], ['/two', '/old']],
        [['/old', '/' + 'a' * 65_535]]
      ].each do |pairs|
        save_rules(*pairs)
        expect(last_response.status).to eq(422)
        expect(JSON.parse(Option.manual_redirects)).to eq('/old' => '/new')
      end
    end
  end

  it 'ignores malformed data and does not intercept API requests' do
    Option.manual_redirects = '{'
    get '/unrelated'
    expect(last_response.status).to eq(404)

    Option.manual_redirects = '{"/api/missing":"/new","/Case/":"/new"}'
    get '/api/missing'
    expect(last_response.status).to eq(404)
    get '/case/'
    expect(last_response.status).to eq(404)
    get '/Case/'
    expect(last_response.status).to eq(302)
  end
end
