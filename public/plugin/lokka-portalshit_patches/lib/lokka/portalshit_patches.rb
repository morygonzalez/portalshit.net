# frozen_string_literal: true

module Lokka
  module PortalshitPatches
    def self.registered(app); end
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
