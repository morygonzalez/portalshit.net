#-*- conding: utf-8 -*-
require "rspec"
require File.dirname(__FILE__) + "/log_loader"

describe EntryInsertion, "p_forum" do
  before(:each) do
    @entries_to_insert = EntryInsertion.new
  end
  
  context "load_entries" do
    it "shouls has 862 articles" do
      logs = @entries_to_insert.load_entries
      logs.length.should == 862 
    end
  end
  
  context "insert_entries" do
    it "should return true" do
      @entries_to_insert.insert_entries.should be_true
    end
  end
end