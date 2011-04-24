#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

#DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/development.sqlite3")

class Category
  include DataMapper::Resource

  property :id, Serial
  property :slug, String, :length => 255
  property :title, String, :length => 255
  property :description, Text
  property :type, String
  property :created_at, DateTime
  property :updated_at, DateTime
  property :parent_id, Integer
end

class SetCategory
  def load_logs
    YAML.load_file("#{Dir.pwd}/p_blog_log.yml")
  end

  def list_categories
    categories = []
    load_logs.each do |log|
      log["category"] = "雑談" if log["category"] == ""
      categories << log["category"]
    end
    make_hash(categories.uniq)
  end

  def make_hash(ary)
    hash = Hash.new
    i = 1
    ary.each do |h|
      hash[i] = h
      i += 1
    end
    return hash
  end

  def insert_categories
    list_categories.each do |k, v|
      @category = Category.create(
        :id => k,
        :slug => nil,
        :title => v,
        :description => v,
        :type => "",
        :created_at => Time.now,
        :updated_at => Time.now,
        :parent_id => nil
      )
      @category.save
    end
  end
end
