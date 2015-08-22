# coding: utf-8
require 'amazon/ecs'
require 'nokogiri'
require 'fileutils'
require 'json'
require_relative 'amazon_associate/fetcher'

module Lokka
  module AmazonAssociate
    def self.registered(app)
      app.get '/admin/plugins/amazon_associate' do
        haml :"plugin/lokka-amazon_associate/views/index", :layout => :"admin/layout"
      end

      app.put '/admin/plugins/amazon_associate' do
        Option.associate_tag = params['associate_tag']
        Option.access_key_id = params['access_key_id']
        Option.secret_key    = params['secret_key']
        flash[:notice] = 'Updated.'
        redirect '/admin/plugins/amazon_associate'
      end

      app.before do
        assets_path = "/plugin/lokka-amazon_associate/assets"
        content_for :header do
          text = <<-EOS.strip_heredoc
            <link href="#{assets_path}/style.css" rel="stylesheet" type="text/css" />
          EOS
        end
      end
    end
  end

  module Helpers
    def associate_link(entry)
      regexp = /<!--\s(?:ISBN|ASIN)=([0-9A-Z]+?)\s-->/
      matches = entry.scan(regexp).flatten
      matches.each do |item_id|
        item = AmazonAssociate::Fetcher.new(item_id)
        next if item.blank?
        element = format_item(item.body)
        entry.gsub!(/<!--\s(?:ISBN|ASIN)=#{item_id}\s-->/, element)
      end

      entry
    end

    def format_item(json)
      begin
        @title, @link, @image, @price, @author, @manufacturer = *nil
        error = json["ItemLookupResponse"]["Items"]["Request"]["Errors"]["Error"] rescue nil
        return @error = "#{error["Code"]}: #{error["Message"]}" if error.present?
        item = json["ItemLookupResponse"]["Items"]["Item"]
        attr = item["ItemAttributes"]
        @title = h!(attr["Title"])         rescue nil
        @link  = item["DetailPageURL"]     rescue nil
        @image = item["MediumImage"]["URL"] rescue nil
        @price = item["OfferSummary"]["LowestNewPrice"]["FormattedPrice"] rescue "-"
        authors = []
        authors << format_authors(attr["Creator"])  if attr["Creator"]
        authors << format_authors(attr["Author"])   if attr["Author"]
        authors << format_authors(attr["Director"]) if attr["Director"]
        authors << format_authors(attr["Actor"])    if attr["Actor"]
        authors << format_authors(attr["Artist"])   if attr["Artist"]
        @author = h! authors.join(", ") if authors.present?
        @manufacturer = attr["Manufacturer"]

        haml :'plugin/lokka-amazon_associate/views/tag', :layout => false
      rescue => e
        puts e
      end
    end

    def format_authors(authors)
      if authors.class == Array && authors.size > 1
        authors.inject([]) {|authors, item|
          authors << item
        }.join(", ")
      else
        authors
      end
    end
  end
end
