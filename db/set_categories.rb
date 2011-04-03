#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "yaml"
require "dm-core"

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite://#{File.dirname(__FILE__)}/development.sqlite3")

class Category
  include DataMapper::Resource
  
  property :id, Integer
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
    YAML.load_file("#{File.dirname(__FILE__)}/p_blog_log.yml")
  end
  
  def list_categories
    categories = []
    load_logs.each do |log|
      if log["category"] == ""
        log["category"] = "雑談"
      end
      categories << log["category"]
    end
    make_hash(categories.uniq)
  end
  
  def make_hash(ary)
    hash = Hash.new
    ary.each do |i, h|
      hash[i] = h
    end
    return hash
  end
  
  def insert_categories
    list_categories.each do |k, v|
      @category = Category.create(
        :id => k,
        :slug => "",
        :title => v,
        :description => v,
        :type => "",
        :create_at => Time.now,
        :updated_at => Time.now,
        :parent_id => nil
      )
      @category.save
    end
  end
end