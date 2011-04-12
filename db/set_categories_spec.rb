#-*- coding: utf-8 -*-

require "rubygems"
require "rspec"
require File.dirname(__FILE__) + "/set_categories"

describe SetCategory, "SetCategory" do
  subject { SetCategory.new }

  context "load_logs" do
    it "ymlを読み込めていること" do
      subject.load_logs.should be_true
    end
    
    it "配列であること" do
      subject.load_logs.should be_kind_of(Array)
    end
  end
  
  context "list_categories" do        
    it "一つ以上の値を持つこと" do
      subject.list_categories.size.should have_at_least(1).item
    end
    
    it "配列の中身が空でないこと" do
      subject.list_categories.should_not include("")
    end
  end

  context "make_hash" do
    it "配列を渡されたときハッシュを返すこと" do
      subject.make_hash([]).should be_kind_of(Hash)
    end
  end
  
  context "insert_categories" do
    it "trueを返すこと" do
      subject.insert_categories.should be_true
    end
  end
end
