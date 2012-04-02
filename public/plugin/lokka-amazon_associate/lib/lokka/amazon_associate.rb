# -*- coding: utf-8 -*-
require 'amazon/ecs'
require 'nokogiri'
require 'fileutils'
require 'digest/md5'
require 'json'

module Lokka
  module AmazonAssociate
    def self.registered(app)
      app.get '/admin/plugins/amazon_associate' do
        haml :"plugin/lokka-amazon_associate/views/index", :layout => :"admin/layout"
      end

      app.put '/admin/plugins/amazon_associate' do
        Option.associate_tag = params['associate_tag']
        Option.access_key_id = params['access_key_id']
        Option.secret_key = params['secret_key']
        flash[:notice] = 'Updated.'
        redirect '/admin/plugins/amazon_associate'
      end
    end
  end

  module Helpers
    def associate_link(entry)
      entry.gsub(/<!--\sISBN=([0-9A-Z]+?)\s-->/m) {
        item = Amazon::Ecs.get_path($1)
        json = Amazon::Ecs.parse_item(item)
        format_item(json)
      }
    end

    def format_item(json)
      error = json["ItemLookupResponse"]["Items"]["Request"]["Errors"]["Error"] rescue nil
      return @error = "#{error["Code"]}: #{error["Message"]}" if error.present?
      item = json["ItemLookupResponse"]["Items"]["Item"]
      attr= item["ItemAttributes"]
      @title = h! attr["Title"] rescue nil
      @link = item["DetailPageURL"] rescue nil
      @image = item["LargeImage"]["URL"] rescue nil
      @price = attr["ListPrice"]["FormattedPrice"] rescue nil
      authors = []
      authors << format_authors(attr["Creator"]) if attr["Creator"]
      authors << format_authors(attr["Author"]) if attr["Author"]
      authors << format_authors(attr["Director"]) if attr["Director"]
      authors << format_authors(attr["Actor"]) if attr["Actor"]
      authors << format_authors(attr["Artist"]) if attr["Artist"]
      @author = h! authors.join(", ")

      haml :'plugin/lokka-amazon_associate/views/tag', :layout => false
    end

    def format_authors(authors)
      if authors.class == Array && authors.size > 1
        authors.inject([]) { |authors, item|
          authors << item
        }.join(", ")
      else
        authors
      end
    end
  end
end

module Amazon
  class Ecs
    def self.get_item(item_id, *args)
      args = {:country => :jp, :response_group => 'Medium'} if args.blank?
      self.options = {
        :associate_tag => Option.associate_tag,
        :AWS_access_key_id => Option.access_key_id,
        :AWS_secret_key => Option.secret_key
      }
      self.item_lookup(item_id, args)
    end

    def self.get_path(item_id)
      dir = File.expand_path("public/plugin/lokka-amazon_associate/tmp")
      url = Digest::MD5.hexdigest item_id
      path = File.join(dir, url.chars.first, url)
      FileUtils.mkdir_p(File.dirname(path))
      return path if File.exists?(path) && File.stat(path).mtime > Time.now.yesterday
      open(path, "w") { |f|
        item = get_item(item_id)
        f.print Hash.from_xml(item.doc.to_xml).to_json
      }
      path
    end

    def self.parse_item(path)
      JSON.parse(File.read(path))
    end
  end
end
