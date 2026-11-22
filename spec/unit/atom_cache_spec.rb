# frozen_string_literal: true

require File.expand_path('../spec_helper', __dir__)

RSpec.describe 'Atom feed cache refresh' do
  let(:post) { build(:post, draft: false) }
  let(:http) { instance_double(Net::HTTP) }
  let(:response) { Net::HTTPOK.new('1.1', '200', 'OK') }

  before do
    allow(Lokka).to receive(:production?).and_return(true)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:get).with('/index.atom').and_return(response)
    allow(post).to receive(:send_ping_to_pubsubhubbub)
    post.send(:mark_atom_feed_changed)
  end

  it 'refreshes the feed before notifying subscribers' do
    expect(http).to receive(:get).with('/index.atom').ordered.and_return(response)
    expect(post).to receive(:send_ping_to_pubsubhubbub).ordered
    post.send(:refresh_atom_cache_and_notify)
  end

  it 'refreshes when a published post becomes a draft' do
    post.draft = true
    post.instance_variable_set(:@atom_feed_changed, false)
    allow(post).to receive(:saved_change_to_draft?).and_return(true)
    allow(post).to receive(:draft_before_last_save).and_return(false)
    post.send(:mark_atom_feed_changed)
    expect(http).to receive(:get).with('/index.atom').and_return(response)
    post.send(:refresh_atom_cache_and_notify)
  end

  it 'does not notify when the refresh fails' do
    allow(http).to receive(:get).and_raise(Timeout::Error)
    expect(post).not_to receive(:send_ping_to_pubsubhubbub)
    post.send(:refresh_atom_cache_and_notify)
  end

  it 'ignores an unchanged draft' do
    post.draft = true
    post.instance_variable_set(:@atom_feed_changed, false)
    post.send(:mark_atom_feed_changed)
    expect(Net::HTTP).not_to receive(:start)
    post.send(:refresh_atom_cache_and_notify)
  end
end
