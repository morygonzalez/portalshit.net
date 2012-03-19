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
        flash[:notice] = 'Updated'
        redirect '/admin/plugins/amazon_associate'
      end
    end
  end

  module Helpers
    def associate_link(entry)
      entry.gsub(/<!-- ?ISBN (.+)? -->.*/m) {
        create_associate_link_tag $1
      }
    end

    def create_associate_link_tag(item_id)
      Amazon::Ecs.options = {
        :associate_tag => Option.associate_tag,
        :AWS_access_key_id => Option.access_key_id,
        :AWS_secret_key => Option.secret_key
      }
      item = Amazon::Ecs.item_lookup(item_id, :country => :jp)
    end
  end
end
