#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require File.dirname(__FILE__) + "/../db/migrator/comment_loader"

describe "Comment" do
  subject { subject = CommentInsertion.new }

  context "#load_comments" do
    it "should return true" do
      subject.load_comments.should be_true
    end
  end

  context "set_comment_entry_id" do
    comment = { "refer_id" => 1175 }
    it "give up refer_id 1175, should return entry_id 865" do
      subject.set_comment_entry_id(comment["refer_id"]).should == 865
    end
  end

  context "#insert_comments" do
    it "should return true" do
      subject.insert_comments.should be_true
    end
  end

  after(:all) do
    Comment.all.destroy
    Comment.repository.adapter.execute('update sqlite_sequence set seq=0 where name="comment";')
  end
end
