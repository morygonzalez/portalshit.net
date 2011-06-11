#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"
require File.dirname(__FILE__) + "/log_loader"

DataMapper::Logger.new(STDOUT, :warn)
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

DataMapper::Model.raise_on_save_failure = true

class CommentInsertion
  def load_comments
    YAML.load_file("#{Dir.pwd}/p_forum.yml")
  end

  def set_comment_entry_id(refer_id)
    @entry = Entry.first(:slug => refer_id)
    return @entry.id.to_i unless @entry.nil?
    return false
  end

  def insert_comments
    load_comments.each do |comment|
      begin
        @comment = Comment.create(
          :entry_id => set_comment_entry_id(comment["refer_id"]),
          :status => comment["trash"] == 0 ? 1 : 0,
          :name => comment["user_name"],
          :homepage => comment["user_uri"],
          :body => comment['comment'],
          :created_at => comment["date"],
          :updated_at => comment["mod"]
        )
        @comment.save
      rescue => e
        next
      end
    end
  end
end
