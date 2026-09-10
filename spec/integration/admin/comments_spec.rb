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
      expect(last_response.body).to include("/admin/comments/#{@comment.id}")
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
      expect(last_response.headers['Location']).to end_with("/admin/comments/#{Comment.last.id}")
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

  context 'GET /admin/comments/:id' do
    it 'shows the comment details and links to its edit form' do
      get "/admin/comments/#{@comment.id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Comment', 'comment-view', @post.link, "/admin/comments/#{@comment.id}/edit")
      expect(last_response.body).to include('comment-reply-form', 'name="reply[body]"')
    end
  end

  context 'PUT /admin/comments/:id' do
    it 'should update the comment"s body ' do
      put "/admin/comments/#{@comment.id}", comment: { body: 'updated' }
      last_response.should be_redirect
      expect(last_response.headers['Location']).to end_with("/admin/comments/#{@comment.id}")
      Comment.find(@comment.id).body.should == 'updated'
    end
  end

  context 'POST /admin/comments/:id/replies' do
    it 'creates an approved public reply and returns to the comment detail' do
      post "/admin/comments/#{@comment.id}/replies", reply: { body: 'Admin public reply' }
      expect(last_response).to be_redirect
      reply = @comment.replies.last
      expect(reply).to have_attributes(entry: @post, private: false, status: Comment::APPROVED, body: 'Admin public reply')
      expect(reply.name).to eq('test')
      expect(last_response.headers['Location']).to end_with("/admin/comments/#{@comment.id}")
    end

    it 'renders the reply form error without creating an empty reply' do
      expect { post "/admin/comments/#{@comment.id}/replies", reply: { body: '' } }.not_to change(Comment, :count)
      expect(last_response).to be_ok
      expect(last_response.body).to include(I18n.t('admin.comment.reply.title'), "name=\"reply[body]\"")
    end

    it 'keeps a reply when its notification cannot be sent' do
      allow_any_instance_of(Lokka::CommentNotifier).to receive(:notify_reply).and_raise(StandardError, 'mail failure')
      expect { post "/admin/comments/#{@comment.id}/replies", reply: { body: 'Saved despite mail failure' } }.to change(Comment, :count).by(1)
      expect(last_response).to be_redirect
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

    context 'GET show' do
      before { get '/admin/comments/9999' }
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
  let!(:private_comment) do
    create(:comment, entry: create(:post), private: true, status: Comment::MODERATED, body: 'Secret admin content')
  end

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

  it 'shows private messages in the detail view and links to their edit form' do
    get "/admin/comments/#{private_comment.id}"
    expect(last_response.body).to include('Secret admin content', I18n.t('admin.comment.private.badge'))
    expect(last_response.body).to include("/admin/comments/#{private_comment.id}/edit")
    expect(last_response.body).to include('comment-reply-form', 'name="reply[body]"')
    expect(last_response.body).not_to include('private-comment-notice')
  end

  it 'shows the privacy note directly below the status select for a private message' do
    get "/admin/comments/#{private_comment.id}/edit"
    expect(last_response.body).to include('Secret admin content')
    document = Nokogiri::HTML(last_response.body)
    note = document.at_css('select#comment_status + .comment-status-note')
    expect(note.text).to eq(I18n.t('admin.comment.private.explanation'))
    expect(document.at_css('#error')).to be_nil
    expect(last_response.body).not_to include('name="comment[private]"')
    expect(last_response.body).to include('name="comment[name]"', 'disabled="disabled"')
  end

  it 'does not show the privacy note for a public comment' do
    public_comment = create(:comment, entry: private_comment.entry)
    get "/admin/comments/#{public_comment.id}/edit"
    expect(last_response).to be_ok
    expect(last_response.body).not_to include('comment-status-note')
  end

  it 'rejects a forged request to clear privacy' do
    put "/admin/comments/#{private_comment.id}", comment: { private: '0' }
    expect(private_comment.reload.private?).to be true
    expect(last_response.body).to include(I18n.t('comment.errors.cannot_be_public'))
  end

  it 'allows spam and moderation changes without notifying the commenter' do
    expect(Lokka::CommentNotifier).not_to receive(:new)
    [Comment::SPAM, Comment::MODERATED].each do |status|
      put "/admin/comments/#{private_comment.id}", comment: { status: status }
      expect(last_response).to be_redirect
      expect(private_comment.reload).to have_attributes(private: true, status: status)
    end
  end

  it 'approves a private message without publishing it or notifying the commenter' do
    expect(Lokka::CommentNotifier).not_to receive(:new)
    put "/admin/comments/#{private_comment.id}", comment: { status: Comment::APPROVED }
    expect(last_response).to be_redirect
    expect(private_comment.reload).to have_attributes(private: true, status: Comment::APPROVED)
    expect(Comment.publicly_visible).not_to include(private_comment)
  end

  it 'creates a private reply for a private message' do
    post "/admin/comments/#{private_comment.id}/replies", reply: { body: 'Admin private reply' }
    expect(last_response).to be_redirect
    reply = private_comment.replies.last
    expect(reply).to have_attributes(private: true, status: Comment::MODERATED, body: 'Admin private reply')
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
