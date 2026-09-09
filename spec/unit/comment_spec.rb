# frozen_string_literal: true

require 'spec_helper'

describe Comment do
  let(:entry) { create(:post) }

  it 'defaults new and database-created comments to public eligibility' do
    expect(Comment.new.private?).to be false
    comment = create(:comment, entry: entry)
    expect(comment.reload.private?).to be false
    expect(Comment.columns_hash['private'].null).to be false
  end

  it 'excludes private comments in every status from public associations and recent comments' do
    public_comment = create(:comment, entry: entry)
    [Comment::MODERATED, Comment::APPROVED, Comment::SPAM].each do |status|
      create(:comment, entry: entry, status: status, private: true)
    end
    create(:comment, entry: entry, status: Comment::MODERATED)
    create(:comment, entry: entry, status: Comment::SPAM)
    expect(Comment.publicly_visible).to eq([public_comment])
    expect(Comment.recent).to eq([public_comment])
    expect(entry.public_comments).to eq([public_comment])
    expect(entry.approved_comments).to eq([public_comment])
    expect(Comment.private_comments.count).to eq(3)
  end

  it 'allows moderation and spam changes but never clearing saved privacy' do
    comment = create(:comment, entry: entry, private: true)
    expect(comment.update(status: Comment::SPAM)).to be true
    expect(comment.update(status: Comment::MODERATED)).to be true
    expect(comment.update(private: false)).to be false
    expect(comment.reload.private?).to be true
  end
end
