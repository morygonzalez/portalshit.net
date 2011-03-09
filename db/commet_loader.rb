#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

DataMapper.setup(:default, 'sqlite:///Users/hitoshi/Sites/lokka/db/development.sqlite3')
DataMapper::Logger.new(STDOUT, :debug)

class Comment
  include DataMapper::Resource
  
  property :id, Serial
  property :entry_id, Integer
  property :status, Integer
  property :name, String
  property :homepage, String, :length => 255
  property :body, Text
  property :created_at, DateTime
  property :updated_at, DateTime
end

p_forum = YAML.load_file("/Users/hitoshi/Downloads/p_forum.yml")
p_forum.each do |f|
  @comment = Comment.create(
    :entry_id => f["refere_id"],
    :status => f["trash"],
    :slug => f["id"],
    :title => f["name"],
    :body => f["comment"],
    :type => "Post",
    :created_at => f["date"],
    :updated_at => f["mod"],
    :frozen_tag_list => f["tag"]
  )
  @comment.save
end