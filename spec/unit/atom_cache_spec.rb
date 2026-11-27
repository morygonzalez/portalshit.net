# frozen_string_literal: true

require File.expand_path('../spec_helper', __dir__)

RSpec.describe 'Atom feed cache purge', :real_commit do
  let(:feed_url) { 'https://portalshit.net/index.atom' }
  let(:zone_id) { '0123456789abcdef0123456789abcdef' }
  let(:token) { 'stubbed-authorization' }
  let(:cloudflare) { instance_double(Net::HTTP) }
  let(:hub) { instance_double(Net::HTTP) }
  let(:purge_response) { Net::HTTPOK.new('1.1', '200', 'OK') }

  before do
    allow(Lokka).to receive(:production?).and_return(true)
    allow(Search).to receive(:add)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLOUDFLARE_ZONE_ID').and_return(zone_id)
    allow(ENV).to receive(:[]).with('CLOUDFLARE_API_TOKEN').and_return(token)
    allow(Net::HTTP).to receive(:start).with(
      'api.cloudflare.com', 443, use_ssl: true, open_timeout: 2, read_timeout: 5, write_timeout: 5
    ).and_yield(cloudflare)
    allow(Net::HTTP).to receive(:start).with(
      'pubsubhubbub.appspot.com', 443, use_ssl: true, open_timeout: 2, read_timeout: 5, write_timeout: 5
    ).and_yield(hub)
    allow(purge_response).to receive(:body).and_return('{"success":true}')
    allow(cloudflare).to receive(:request).and_return(purge_response)
    allow(hub).to receive(:request).and_return(Net::HTTPNoContent.new('1.1', '204', 'No Content'))
  end

  it 'purges the public URL after the commit and then notifies the hub' do
    post = build(:post)

    expect(cloudflare).to receive(:request).ordered do |request|
      expect(Entry.connection.transaction_open?).to be(false)
      expect(Post.published.exists?(post.id)).to be(true)
      expect(request.method).to eq('POST')
      expect(request.path).to eq("/client/v4/zones/#{zone_id}/purge_cache")
      expect(request['Authorization']).to eq("Bearer #{token}")
      expect(request.content_type).to eq('application/json')
      expect(JSON.parse(request.body)).to eq('files' => [feed_url])
      purge_response
    end
    expect(hub).to receive(:request).ordered do |request|
      expect(request.method).to eq('POST')
      expect(request.path).to eq('/')
      expect(URI.decode_www_form(request.body).to_h).to eq('hub.mode' => 'publish', 'hub.url' => feed_url)
      Net::HTTPNoContent.new('1.1', '204', 'No Content')
    end

    Entry.transaction do
      post.save!
      expect(Net::HTTP).not_to have_received(:start)
    end
  end

  it 'purges when a draft is published, a public post is edited or unpublished, or a public post is deleted' do
    post = create(:post, draft: true)
    expect(cloudflare).not_to have_received(:request)

    [
      -> { post.update!(draft: false) },
      -> { post.update!(title: 'New title') },
      -> { post.update!(draft: true) },
      -> { post.update!(draft: false) },
      -> { post.destroy! }
    ].each_with_index do |change, index|
      change.call
      expect(cloudflare).to have_received(:request).exactly(index + 1).times
    end
    expect(hub).to have_received(:request).exactly(5).times
  end

  it 'skips drafts, pages, unchanged saves, and rolled-back changes' do
    post = create(:post, draft: true)
    post.update!(title: 'Still a draft')
    post.destroy!
    create(:page, draft: false)

    published = create(:post)
    published.save!
    Entry.transaction do
      published.update!(title: 'Discarded')
      raise ActiveRecord::Rollback
    end

    expect(cloudflare).to have_received(:request).once
    expect(hub).to have_received(:request).once
  end

  it 'preserves the publication and skips the notification on an HTTP error' do
    allow(cloudflare).to receive(:request).and_return(Net::HTTPForbidden.new('1.1', '403', 'Forbidden'))

    expect(create(:post).reload).to be_published
    expect(hub).not_to have_received(:request)
  end

  it 'skips the notification if Cloudflare reports failure with HTTP 200' do
    allow(purge_response).to receive(:body).and_return('{"success":false}')

    expect(create(:post).reload).to be_published
    expect(hub).not_to have_received(:request)
  end

  it 'preserves the publication and skips the notification on a timeout' do
    allow(cloudflare).to receive(:request).and_raise(Net::ReadTimeout)

    expect(create(:post).reload).to be_published
    expect(hub).not_to have_received(:request)
  end

  it 'logs an invalid API response to stderr without including its body' do
    allow(ActiveRecord::Base).to receive(:logger).and_return(nil)
    allow(purge_response).to receive(:body).and_return(token)

    expect { create(:post) }.to output(
      /\ACloudflare Atom cache purge failed for entry \d+ \(JSON::ParserError\)\n\z/
    ).to_stderr
    expect(hub).not_to have_received(:request)
  end

  it 'notifies the hub when Cloudflare credentials are incomplete' do
    allow(ENV).to receive(:[]).with('CLOUDFLARE_API_TOKEN').and_return(nil)

    expect(create(:post).reload).to be_published
    expect(cloudflare).not_to have_received(:request)
    expect(hub).to have_received(:request).once
  end

  it 'preserves the publication when notifying the hub fails' do
    allow(hub).to receive(:request).and_raise(Net::OpenTimeout)

    expect(create(:post).reload).to be_published
    expect(cloudflare).to have_received(:request).once
  end
end
