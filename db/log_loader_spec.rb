#!/usr/bin/env ruby
#-*- conding: utf-8 -*-

require "rubygems"
require "rspec"
require File.dirname(__FILE__) + "/log_loader"

describe EntryInsertion, "p_blog_log" do
  subject { EntryInsertion.new }

  context "#load_entries" do
    it "should has 862 articles" do
      subject.load_entries.length.should == 862
    end
  end

  context "#insert_categories" do
    it "should return true" do
      subject.insert_categories.should be_true
    end
  end

  context "#get_categories" do
    it "should be 9" do
      subject.get_categories.length.should == 9
    end

    it "should be instance of Array" do
      subject.get_categories.should be_kind_of(Array)
    end
  end

  context "#set_entry_category_id" do
    it "should set entry's category_id" do
      entry = { "category" => "WWW" }
      subject.set_entry_category_id(entry).should == 1
    end
  end

  context "#insert_entries" do
    it "should return true" do
      subject.insert_entries.should be_true
    end
  end

  context "check inserted entries" do
    it "should return 862" do
      Entry.all.length.should == 862
    end
  end

  after(:all) do
    Category.all.destroy
    Entry.all.destroy
    Entry.repository.adapter.execute('update sqlite_sequence set seq=0 where name="entries";')
  end
end
