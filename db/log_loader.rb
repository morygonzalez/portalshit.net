#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

DataMapper::Logger.new("log_loader.log", :debug)
DataMapper.setup(:default, "sqlite://#{File.dirname(__FILE__)}/development.sqlite3")

class Entry
  include DataMapper::Resource
  
  property :id, Integer
  property :user_id, Integer
  property :category_id, Integer
  property :slug, String, :length => 255
  property :title, String, :length => 255
  property :body, Text
  property :type, String
  property :draft, Boolean, :default => false
  property :created_at, DateTime
  property :updated_at, DateTime
  property :frozen_tag_list, String
end

class EntryInsertion
  def load_entries
    YAML.load_file("#{File.dirname(__FILE__)}/p_blog_log.yml")
  end
  
  def insert_entries
    load_entries.each do |l|
      @entry = Entry.create(
        :id => l["id"],
        :user_id => 1,
        :category_id => l["category"],
        :slug => "",
        :title => l["name"],
        :body => l["comment"],
        :type => "Post",
        :created_at => l["date"],
        :updated_at => l["mod"],
        :frozen_tag_list => l["tag"]
      )
      @entry.save
    end
  end
end

@insertion = EntryInsertion.new
@insertion.insert_entries
