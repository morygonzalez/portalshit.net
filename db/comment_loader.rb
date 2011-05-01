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
  def initialize
    get_entries
  end

  def load_comments
    YAML.load_file("#{Dir.pwd}/p_forum.yml")
  end

  def get_entries
    @entries = Entry.all
  end

  def set_comment_entry_id(comment)
    @entries[comment["refer_id"]].slug.to_i
  end

  def insert_comments
    load_comments.each do |comment|
      @comment = Comment.create(
        :entry_id => comment["refer_id"],
        :status => comment["trash"] == 0 ? 1 : 0,
        :name => comment["user_name"],
        :homepage => comment["user_uri"],
        :body => comment['comment'],
        :created_at => comment["date"],
        :updated_at => comment["mod"]
      )
      @comment.save
    end
  end
end
