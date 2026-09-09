# frozen_string_literal: true

require 'spec_helper'

describe Lokka::CommentNotifier do
  let(:comment) { create(:comment, entry: create(:post), private: true) }
  let(:notifier) { described_class.new(comment) }
  let(:client) { instance_double(Aws::SESV2::Client, send_email: {}) }

  before do
    comment # callbacks run in the test environment before stubbing the environment
    allow(Aws::SESV2::Client).to receive(:new).and_return(client)
  end

  it 'never sends real mail in the test environment' do
    expect(Aws::SESV2::Client).not_to receive(:new)
    notifier.notify_author
    notifier.notify_commenter
  end

  context 'outside the test environment' do
    before { allow(Lokka).to receive(:test?).and_return(false) }

    it 'sends private content only to the entry author with an admin link' do
      expect(client).to receive(:send_email) do |params|
        expect(params[:destination][:to_addresses]).to eq([comment.entry.user.email])
        mail = params[:content][:simple]
        expect(mail[:subject][:data]).to include('メッセージが届きました', comment.entry.title)
        expect(mail[:body][:text][:data]).to include(comment.name, comment.body, "/admin/comments/#{comment.id}/edit")
        expect(mail[:body]).not_to have_key(:html)
      end
      notifier.notify_author
    end

    it 'does not send approval mail for an approved private comment' do
      expect(client).not_to receive(:send_email)
      notifier.notify_commenter
    end

    it 'keeps ordinary approval mail and skips private author notifications for ordinary comments' do
      # Avoid existing production callbacks while building the ordinary notification fixture.
      ordinary = build(:comment, entry: create(:post))
      expect(client).to receive(:send_email).with(hash_including(destination: { to_addresses: [ordinary.email] }))
      described_class.new(ordinary).notify_commenter
      described_class.new(ordinary).notify_author
    end

    it 'does not send a second notification through the legacy plugin callback' do
      expect(client).not_to receive(:send_email)
      comment.send(:send_notification_to_entry_author)
    end
  end
end
