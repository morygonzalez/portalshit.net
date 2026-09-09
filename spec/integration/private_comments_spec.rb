# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Private comment submission and public display' do
  include_context 'in site'
  let(:entry) { create(:post) }
  let(:payload) { { check: 'check', comment: attributes_for(:comment).except(:status).merge(private: '1') } }

  before do
    allow_any_instance_of(Lokka::CommentNotifier).to receive(:notify_author)
  end

  it 'saves a private submission and notifies the author only after a successful save' do
    expect_any_instance_of(Lokka::CommentNotifier).to receive(:notify_author) do |_notifier|
      expect(Comment.private_comments.count).to eq(1)
    end
    post entry.link, payload
    expect(last_response).to be_redirect
    expect(Comment.last.private?).to be true
  end

  it 'does not notify the author for ordinary submissions' do
    payload[:comment].delete(:private)
    expect_any_instance_of(Lokka::CommentNotifier).not_to receive(:notify_author)
    post entry.link, payload
    expect(last_response).to be_redirect
    expect(Comment.last.private?).to be false
  end

  it 'keeps validation failures private and does not send mail' do
    payload[:comment][:email] = ''
    expect_any_instance_of(Lokka::CommentNotifier).not_to receive(:notify_author)
    expect { post entry.link, payload }.not_to change(Comment, :count)
  end

  it 'preserves privacy when the NG words filter marks the comment as spam' do
    Option.ng_words = 'Test Comment'
    post entry.link, payload
    expect(Comment.last).to have_attributes(private: true, status: Comment::SPAM)
  end

  it 'keeps the saved comment and redirects even when notification fails' do
    allow_any_instance_of(Lokka::CommentNotifier).to receive(:notify_author).and_raise(StandardError, 'sensitive message')
    expect { post entry.link, payload }.to change(Comment.private_comments, :count).by(1)
    expect(last_response).to be_redirect
  end

  context 'submission receipt' do
    before do
      # Render the entry template without unrelated portalshit integrations.
      allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
        app.haml :'theme/portalshit/entry', layout: false
      end
      allow_any_instance_of(Lokka::App).to receive(:partial).and_return('')
    end

    it 'shows a one-time private receipt tied to the submitted entry' do
      post entry.link, payload
      follow_redirect!
      expect(last_response.body).to include(I18n.t('theme.comment.private.thanks'))
      expect(last_response.headers['cache-control']).to include('no-store')
      get entry.link
      expect(last_response.body).not_to include(I18n.t('theme.comment.private.thanks'))
    end

    it 'does not show the receipt on a different entry' do
      other_entry = create(:post)
      post entry.link, payload
      get other_entry.link
      expect(last_response.body).not_to include(I18n.t('theme.comment.private.thanks'))
      get entry.link
      expect(last_response.body).to include(I18n.t('theme.comment.private.thanks'))
    end

    it 'does not trust receipt query parameters' do
      get "#{entry.link}?comment_submitted=1&private=1"
      expect(last_response.body).not_to include(I18n.t('theme.comment.private.thanks'), I18n.t('theme.comment.thanks'))
    end

    it 'shows the ordinary receipt for an ordinary submission' do
      payload[:comment].delete(:private)
      post entry.link, payload
      follow_redirect!
      expect(last_response.body).to include(I18n.t('theme.comment.thanks'))
      expect(last_response.body).not_to include(I18n.t('theme.comment.private.thanks'))
    end
  end

  %w[jarvi jarvi_mobile curvy toimisto one-column-neue harmaa Farikal portalshit notebook vicuna-mono].each do |theme|
    it "does not expose approved private content in the #{theme} entry template" do
      visible = create(:comment, entry: entry, name: 'PublicReader', body: 'VisibleComment')
      secret = create(:comment, entry: entry, private: true, name: 'SecretReader', body: 'SecretBody', homepage: 'https://secret.example', email: 'secret@example.com')
      allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
        engine = File.exist?("public/theme/#{theme}/entry.haml") ? :haml : :erb
        app.send(engine, :"theme/#{theme}/entry", layout: false)
      end
      allow_any_instance_of(Lokka::App).to receive(:partial).and_return('')
      get entry.link
      expect(last_response).to be_ok
      [secret.name, secret.body, secret.homepage, Digest::MD5.hexdigest(secret.email), "comment-#{secret.id}"].each do |value|
        expect(last_response.body).not_to include(value)
      end
      expect(last_response.body).to include(visible.body) unless %w[jarvi notebook vicuna-mono].include?(theme)
    end
  end
end

describe 'Private comment form' do
  include_context 'in site'
  let(:entry) { create(:post) }

  before do
    allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
      app.haml :'theme/portalshit/comment', layout: false, locals: { disabled: false }
    end
  end

  it 'renders public and private comment tabs with a clear explanation' do
    get entry.link
    document = Nokogiri::HTML(last_response.body)
    tabs = document.css('input[name="comment[private]"]')
    expect(tabs.map { |tab| tab['type'] }).to eq(%w[radio radio])
    expect(tabs.map { |tab| tab['value'] }).to eq(%w[0 1])
    expect(tabs.first['checked']).not_to be_nil
    expect(tabs.last['checked']).to be_nil
    expect(document.at_css('label[for="comment_public"]').text).to eq(I18n.t('theme.comment.mode.public'))
    expect(document.at_css('label[for="comment_private"]').text).to eq(I18n.t('theme.comment.mode.private'))
    expect(document.at_css('.comment-visibility-public').text).to eq(I18n.t('theme.comment.note'))
    expect(document.at_css('.comment-visibility-private').text).to eq(I18n.t('theme.comment.private.explanation'))
    expect(document.at_css('.comment-submit-public')['value']).to eq(I18n.t('theme.comment.submit.public'))
    expect(document.at_css('.comment-submit-private')['value']).to eq(I18n.t('theme.comment.submit.private'))
  end

  it 'keeps the private tab selected on validation failure' do
    post entry.link, check: 'check', comment: { private: '1', name: 'Reader', body: 'Private text', email: '' }
    document = Nokogiri::HTML(last_response.body)
    expect(document.at_css('#comment_private')['checked']).not_to be_nil
    expect(document.at_css('#comment_public')['checked']).to be_nil
    expect(Comment.count).to eq(0)
  end
end

describe 'Public comment sidebars and counts' do
  include_context 'in site'
  let(:entry) { create(:post) }
  let!(:secret) { create(:comment, entry: entry, private: true, body: 'SecretSidebar') }

  %w[curvy/side jarvi_mobile/layout].each do |template|
    it "excludes private content and links from #{template}" do
      create(:comment, entry: entry, body: 'PublicSidebar')
      allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
        app.erb :"theme/#{template}", layout: false do
          ''
        end
      end
      get entry.link
      expect(last_response).to be_ok
      expect(last_response.body).to include('PublicSidebar')
      expect(last_response.body).not_to include('SecretSidebar', "#comment-#{secret.id}")
    end
  end

  it 'counts only approved public comments on the article and article list' do
    create(:comment, entry: entry)
    create(:comment, entry: entry, status: Comment::MODERATED)
    allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
      app.haml :'theme/portalshit/entry', layout: false
    end
    allow_any_instance_of(Lokka::App).to receive(:partial).and_return('')
    get entry.link
    expect(Nokogiri::HTML(last_response.body).at_css('.comment a').text).to include('(1)')

    allow_any_instance_of(Lokka::App).to receive(:render_detect_with_options) do |app|
      app.haml :'theme/portalshit/article', layout: false, locals: { post: entry }
    end
    get entry.link
    expect(Nokogiri::HTML(last_response.body).at_css('.comment a').text).to include('(1)')
  end
end
