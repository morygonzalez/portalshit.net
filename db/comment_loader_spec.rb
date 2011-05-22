#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require "rspec"
require File.dirname(__FILE__) + "/comment_loader"

describe "Comment" do
  subject { subject = CommentInsertion.new }

  context "#load_comments" do
    it "should return true" do
      subject.load_comments.should be_true
    end
  end

  context "#insert_comments" do
    it "should return true" do
      subject.insert_comments.should be_true
    end
  end

  context "#get_entries" do
    it "should have 862 entries" do
      subject.get_entries.size.should == 862
    end
  end

  context "set_comment_entry_id" do
    comment = { "refer_id" => 513 }
    it "give up refer_id 513, should return entry_id 821" do
      subject.set_comment_entry_id(comment).should == 821
    end
  end

  after(:all) do
    Comment.all.destroy
    Comment.repository.adapter.execute('update sqlite_sequence set seq=0 where name="comment";')
  end
end
