#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

DataMapper.setup(:default, 'sqlite:///Users/hitoshi/Sites/lokka/db/development.sqlite3')
DataMapper::Logger.new(STDOUT, :debug)

class Entry
  include DataMapper::Resource
  
  property :id, Integer
  property :user_id, Integer
  property :category_id, Integer
  property :slug, String, :length => 255
  property :title, String, :length => 255
  property :body, Text
  property :type, String
  property :created_at, DateTime
  property :updated_at, DateTime
  property :frozen_tag_list, String
end

logs = YAML.load_file("/Users/hitoshi/Downloads/portalshit.yml")
logs.each do |l|
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