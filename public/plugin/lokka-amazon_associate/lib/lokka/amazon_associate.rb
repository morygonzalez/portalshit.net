# coding: utf-8
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
      entry.gsub(/<!--\s(?:ISBN|ASIN)=([0-9A-Z]+?)\s-->/m) {
        item = get_path($1)
        json = parse_item(item)
        format_item(json)
      }
    end

    def format_item(json)
      begin
        @title, @link, @image, @price, @author, @manufacturer = *nil
        error = json["ItemLookupResponse"]["Items"]["Request"]["Errors"]["Error"] rescue nil
        return @error = "#{error["Code"]}: #{error["Message"]}" if error.present?
        item = json["ItemLookupResponse"]["Items"]["Item"]
        attr= item["ItemAttributes"]
        @title = h! attr["Title"] rescue nil
        @link = item["DetailPageURL"] rescue nil
        @image = item["LargeImage"]["URL"] rescue nil
        @price = item["OfferSummary"]["LowestNewPrice"]["FormattedPrice"] rescue "-"
        authors = []
        authors << format_authors(attr["Creator"]) if attr["Creator"]
        authors << format_authors(attr["Author"]) if attr["Author"]
        authors << format_authors(attr["Director"]) if attr["Director"]
        authors << format_authors(attr["Actor"]) if attr["Actor"]
        authors << format_authors(attr["Artist"]) if attr["Artist"]
        @author = h! authors.join(", ") if authors.present?
        @manufacturer = attr["Manufacturer"]

        haml :'plugin/lokka-amazon_associate/views/tag', :layout => false
      rescue => e
        "#{e}: malformed JSON"
      end
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

    def get_item(item_id, *args)
      args = {:country => :jp, :response_group => 'Medium'} if args.blank?
      Amazon::Ecs.options = {
        :associate_tag => Option.associate_tag,
        :AWS_access_key_id => Option.access_key_id,
        :AWS_secret_key => Option.secret_key
      }
      Amazon::Ecs.item_lookup(item_id, args)
    end

    def get_path(item_id)
      dir = File.expand_path("tmp/amazon")
      url = Digest::MD5.hexdigest item_id
      path = File.join(dir, url.chars.first, url)
      FileUtils.mkdir_p(File.dirname(path))
      return path if File.exists?(path) && File.stat(path).mtime > Time.now.yesterday
      open(path, "w") { |f|
        item = get_item(item_id)
        f.print Hash.from_xml(item.doc.to_xml).to_json
        sleep 1
      }
      path
    end

    def parse_item(path)
      JSON.parse(File.read(path))
    end
  end
end
