# -*- coding: utf-8 -*-
require 'amazon/ecs'

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
      entry.gsub(/<!-- ?ISBN=(.+)? -->/m) {
        format_item get_item($1)
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

    def format_item(item)
      @title  = item.doc.css("ItemAttributes Title").first.inner_text
      @link   = item.doc.css("DetailPageURL").first.inner_text
      @image  = item.doc.css("MediumImage URL").first.inner_text
      @price  = item.doc.css("ListPrice FormattedPrice").first.inner_text rescue nil
      authors = []
      attr    = item.doc.css("ItemAttributes")
      authors << format_authors(attr.css("Creator")) if attr.css("Creator").present?
      authors << format_authors(attr.css("Author")) if attr.css("Author").present?
      authors << format_authors(attr.css("Director")) if attr.css("Director").present?
      authors << format_authors(attr.css("Actor")) if attr.css("Actor").present?
      @author = authors.join(", ")

      haml :'plugin/lokka-amazon_associate/views/tag', :layout => false
    end

    def format_authors(authors)
      if authors.count > 1
        authors.inject([]) { |authors, item|
          authors << item.inner_text
        }.join(", ")
      else
        authors.first.inner_text
      end
    end
  end
end
