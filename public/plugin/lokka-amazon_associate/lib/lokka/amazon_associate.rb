# coding: utf-8
require 'amazon/ecs'
require 'nokogiri'
require 'fileutils'
require 'json'
require_relative 'amazon_associate/fetcher'

module Lokka
  module AmazonAssociate
    def self.registered(app)
      app.get '/amazon/?:item_id?.json' do |item_id|
        item = AmazonAssociate::Fetcher.new(item_id)

        content_type :json
        item.body.to_json
      end

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
            <script src="#{assets_path}/script.js"></script>
            <link href="#{assets_path}/style.css" rel="stylesheet" type="text/css" />
          EOS
        end
      end
    end
  end
end
