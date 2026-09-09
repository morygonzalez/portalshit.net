# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe '/admin/comments' do
  include_context 'admin login'

  before do
    @post = create(:post)
    @comment = create(:comment, entry: @post)
    create(:spam_comment, entry: @post)
  end

  after do
    Comment.delete_all
    Post.delete_all
  end

  context 'GET /admin/comments' do
    it 'should show index' do
      get '/admin/comments'
      last_response.should be_ok
    end
  end

  context 'GET /admin/comments/new' do
    it 'should show form for new comment' do
      get '/admin/comments/new'
      last_response.should be_ok
      last_response.body.should match('<form')
    end
  end

  context 'POST /admin/comments' do
    it 'should create a new comment' do
      Comment.delete_all
      sample = attributes_for(:comment, entry_id: @post.id)
      post '/admin/comments', { comment: sample }
      last_response.should be_redirect
      expect(Post.find(@post.id).comments.count).to eq(1)
    end
  end

  context 'GET /admin/comments/:id/edit' do
    it 'should show edit comment' do
      get "/admin/comments/#{@comment.id}/edit"
      last_response.body.should match('<form')
      last_response.body.should match('Test Comment')
    end
  end

  context 'PUT /admin/comments/:id' do
    it 'should update the comment"s body ' do
      put "/admin/comments/#{@comment.id}", comment: { body: 'updated' }
      last_response.should be_redirect
      Comment.find(@comment.id).body.should == 'updated'
    end
  end

  context 'DELETE /admin/comments/:id' do
    it 'should delete the comment' do
      delete "/admin/comments/#{@comment.id}"
      last_response.should be_redirect
      Comment.where(id: @comment.id).first.should be_nil
    end
  end

  context 'delete /admin/comments/spam' do
    it 'should delete spam comments' do
      delete '/admin/comments/spam'
      last_response.should be_redirect
      Comment.spam.size.should eq(0)
    end
  end

  context 'delete /admin/comments/selected' do
    context 'When single id has been posted' do
      it 'should delete selected comment' do
        delete '/admin/comments/selected', selected_comment_ids: @comment.id
        last_response.should be_redirect
        Comment.where(id: @comment.id).should be_blank
      end
    end

    context 'When multiple ids have been posted' do
      before do
        @another_comment = create(:comment, entry: @post)
      end

      let :params do
        { selected_comment_ids: [@comment.id, @another_comment.id].join(',') }
      end

      it 'should delete selected comments' do
        delete '/admin/comments/selected', params
        last_response.should be_redirect
        Comment.where(id: [@comment.id, @another_comment.id]).should be_blank
      end
    end
  end

  context 'when the comment does not exist' do
    before { Comment.delete_all }

    context 'GET' do
      before { get '/admin/comments/9999/edit' }
      it_behaves_like 'a not found page'
    end

    context 'PUT' do
      before { put '/admin/comments/9999' }
      it_behaves_like 'a not found page'
    end

    context 'DELETE' do
      before { delete '/admin/comments/9999' }
      it_behaves_like 'a not found page'
    end
  end

  context "When <xmp> tag is used in comment author's name" do
    before do
      @comment.update(name: '<xmp>')
    end

    context 'GET /admin/comments' do
      it 'should escape html tag' do
        get '/admin/comments'
        last_response.body.should match(/&lt;xmp&gt;/)
      end
    end
  end
end

describe 'Private comment administration' do
  include_context 'admin login'
  let!(:private_comment) { create(:comment, entry: create(:post), private: true, body: 'Secret admin content') }

  it 'lists private content with a badge and filters out ordinary comments' do
    create(:comment, entry: private_comment.entry, body: 'Ordinary admin content')
    get '/admin/comments?private=1'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Secret admin content', 'private-comment-badge')
    expect(last_response.body).not_to include('Ordinary admin content')
    expect(last_response.body).to include('<ul class="conditions">')
  end

  it 'filters public comments separately from private messages' do
    public_comment = create(:comment, entry: private_comment.entry, body: 'Public filtered content')
    get '/admin/comments?type=public'
    expect(last_response.body).to include(I18n.t('admin.comment.public.filter'), 'Public filtered content')
    expect(last_response.body).not_to include('Secret admin content')

    get '/admin/comments?type=private'
    expect(last_response.body).to include(I18n.t('admin.comment.private.filter'), 'Secret admin content')
    expect(last_response.body).not_to include('Public filtered content')
  end

  it 'labels ordinary comments as comments' do
    ordinary = create(:comment, entry: private_comment.entry, body: 'Ordinary labeled content')
    get '/admin/comments'
    expect(last_response.body).to include(I18n.t('admin.comment.public.badge'), 'public-comment-badge', 'Ordinary labeled content')
  end

  it 'explains privacy in the edit form without a privacy toggle' do
    get "/admin/comments/#{private_comment.id}/edit"
    expect(last_response.body).to include('Secret admin content', I18n.t('admin.comment.private.explanation'))
    expect(last_response.body).not_to include('name="comment[private]"')
    expect(last_response.body).to include('name="comment[name]"', 'disabled="disabled"')
  end

  it 'rejects a forged request to clear privacy' do
    put "/admin/comments/#{private_comment.id}", comment: { private: '0' }
    expect(private_comment.reload.private?).to be true
    expect(last_response.body).to include(I18n.t('comment.errors.cannot_be_public'))
  end

  it 'allows spam and moderation changes without notifying the commenter' do
    expect(Lokka::CommentNotifier).not_to receive(:new)
    [Comment::SPAM, Comment::MODERATED, Comment::APPROVED].each do |status|
      put "/admin/comments/#{private_comment.id}", comment: { status: status }
      expect(last_response).to be_redirect
      expect(private_comment.reload).to have_attributes(private: true, status: status)
    end
  end

  it 'can delete private comments' do
    delete "/admin/comments/#{private_comment.id}"
    expect(Comment.exists?(private_comment.id)).to be false
  end

  it 'does not expose admin content after logout' do
    get '/admin/logout'
    get "/admin/comments/#{private_comment.id}/edit"
    expect(last_response).to be_redirect
    expect(last_response.body).not_to include('Secret admin content')
    get '/admin/comments?private=1'
    expect(last_response).to be_redirect
    expect(last_response.body).not_to include('Secret admin content')
  end
end
