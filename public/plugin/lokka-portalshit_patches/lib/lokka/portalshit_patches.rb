# frozen_string_literal: true

module Lokka
  module PortalshitPatches
    def self.registered(app)
      app.get '/index.atom' do
        @posts = Post.preload(:category, :user).
                   published.
                   page(params[:page] || 1).
                   per(100).
                   order(@site.default_order)
        @posts = apply_continue_reading(@posts)

        content_type 'application/atom+xml', charset: 'utf-8'
        builder :'lokka/index'
      end
    end
  end
end

class Entry
  def long_description
    content = body.strip.gsub(/<\/?[^>]*>/, "").gsub(/[\t]+/, ' ').gsub(/[\r\n]/, '')[0..120]
    sprintf '%s...', content
  end

  def images
    body.scan(/<img.+?src="(.+?)".+?>/).flatten
  end

  def cover_image
    images.first || 'https://portalshit.net/theme/portalshit/ogp_image.png'
  end
end
