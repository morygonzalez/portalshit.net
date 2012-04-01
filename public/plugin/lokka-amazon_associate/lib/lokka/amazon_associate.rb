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
        item = get_item($1)
        # path = Amazon::Ecs.get_path(item)
        # json = Amazon::Ecs.parse_item(path)
        format_item(json)
      }
    end

    def get_item(item_id, *args)
      args = {:country => :jp, :response_group => 'Medium'} if args.blank?
      Amazon::Ecs.options = {
        :associate_tag => Option.associate_tag,
        :AWS_access_key_id => Option.access_key_id,
        :AWS_secret_key => Option.secret_key
      }
      Amazon::Ecs.item_lookup(item_id, args)
    end

    def format_item(json)
      item = json["ItemLookupResponse"]["Items"]["Item"]
      attr= item["ItemAttributes"]
      @title = attr["Title"] rescue nil
      @link = item["DetailPageURL"] rescue nil
      @image = item["LargeImage"]["URL"] rescue nil
      @price = attr["ListPrice"]["FormattedPrice"] rescue nil
      authors = []
      authors << format_authors(attr["Creator"]) if attr["Creator"]
      authors << format_authors(attr["Author"]) if attr["Author"]
      authors << format_authors(attr["Director"]) if attr["Director"]
      authors << format_authors(attr["Actor"]) if attr["Actor"]
      authors << format_authors(attr["Artist"]) if attr["Artist"]
      @author = authors.join(", ")

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
    def item_lookup(item_id, args)
      super
    end

    def self.get_path(item)
      dir = File.expand_path("public/plugin/lokka-amazon_associate/tmp")
      url = Digest::MD5.hexdigest item.doc.css("ItemId").inner_text
      path = File.join(dir, url.chars.first, url)
      FileUtils.mkdir_p(File.dirname(path))
      return path if File.exists?(path)
      open(path, "w") { |f|
        f.print Hash.from_xml(item.doc.to_xml).to_json
      }
      path
    end

    def self.parse_item(path)
      JSON.parse(File.read(path))
    end
  end
end
