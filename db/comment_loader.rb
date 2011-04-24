#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/development.sqlite3")

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

class CommentInsertion
  def load_comments
    return YAML.load_file("#{Dir.pwd}/p_forum.yml")
  end

  def insert_comments
    load_comments.each do |f|
      comment = Comment.create(
        :entry_id => f["refer_id"],
        :status => f["trash"] == 0 ? 1 : 0,
        :name => f["user_name"],
        :homepage => f["user_uri"],
        :body => f['comment'],
        :created_at => f["date"],
        :updated_at => f["mod"]
      )
      comment.save
    end
  end
end
