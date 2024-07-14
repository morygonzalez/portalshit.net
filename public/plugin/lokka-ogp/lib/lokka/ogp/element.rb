# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'faraday_middleware'
require 'addressable'

module Lokka
  module OGP
    class Element
      CACHE_DIR = "#{Lokka.root}/tmp/ogp"

      attr_reader :url

      def initialize(url)
        @url = begin
                 url = url.force_encoding('utf-8')
                 if url =~ /%/ || Addressable::URI.unescape(url) == url
                   url
                 else
                   Addressable::URI.encode(url)
                 end
               end
      end

      def url_to_request
        if @url =~ /wikipedia\.org/
          parsed = URI.parse(Addressable::URI.escape(@url))
          title = @url.split('/').last
          %(#{parsed.scheme}://#{parsed.hostname}/w/index.php?title=#{title})
        else
          @url
        end
      end

      def host
        @host ||= URI.parse(url).host
      end

      def scheme
        @scheme ||= URI.parse(url).scheme
      end

      def title
        @title ||= opengraph&.og&.title.presence || title_fallback || url
      end

      def image
        @image ||= opengraph&.og&.images&.find {|item| item.url.presence } || image_fallback
      end

      def description
        @description ||= opengraph&.og&.description.presence || description_fallback
      end

      def exist?
        File.exist?(cache_path) && test('M', File.open(cache_path)) > 1.month.ago
      end

      def create
        FileUtils.mkdir_p(CACHE_DIR)
        File.open(cache_path, 'w') do |file|
          file.puts html
        end
        true
      rescue Errno::ENAMETOOLONG => e
        puts e.message
      end

      def uname
        @uname ||= OpenSSL::Digest::MD5.new(url).hexdigest
      end

      private

      def opengraph
        @opengraph ||= OpenGraphReader.fetch(url_to_request)
      end

      def cache_path
        File.join(CACHE_DIR, uname)
      end

      def doc
        @doc ||= begin
                   connection = Faraday.new do |builder|
                     builder.response :follow_redirects
                     builder.adapter Faraday.default_adapter
                   end
                   response = connection.get(url_to_request)
                   Nokogiri::HTML(response.body)
                 rescue StandardError
                   nil
                 end
      end

      def title_fallback
        doc&.xpath('//head/title')&.text
      end

      def image_fallback
        og_image_url = doc&.xpath('//head/meta[@property="og:image"]')&.first.try(:[], 'content')
        favicon_url = doc&.xpath('//head/link[@rel="icon" or @rel="shortcut icon"]')&.first.try(:[], 'href')
        target_url = og_image_url.presence || favicon_url.presence
        fallback_url = '/plugin/lokka-ogp/assets/no-image.png'
        parsed_url = URI.parse(target_url.to_s)
        case
        when parsed_url.absolute?
          parsed_url
        when parsed_url.relative? && parsed_url.host.present?
          %Q(#{scheme}:#{parsed_url})
        when parsed_url.relative? && parsed_url.host.blank? && parsed_url.path.present?
          %Q(#{scheme}://#{host}#{parsed_url.path})
        else
          fallback_url
        end
      end

      def description_fallback
        doc&.xpath('//head/meta[@property="og:description"]')&.first.try(:[], 'content')&.to_s ||
          doc&.xpath('//head/meta[@name="description"]')&.first.try(:[], 'content')&.to_s
      end

      def secure_image
        if use_proxy?
          "https://portalshit.net/imageproxy/120/#{image}"
        else
          image
        end
      end

      def use_proxy?
        exclude_regexp = /(githubusercontent|=\d|token=\w+)/
        image.to_s.start_with?('http') && !image.to_s.match(exclude_regexp)
      end

      def html
        template = <<~ERUBY
          <div class="ogp">
            <a href="<%= url %>" class="ogp-link" target="_parent">
              <div class="ogp-element">
                <div class="ogp-image">
                  <img src="<%= secure_image %>" alt="<%= html_escape(title) %>" />
                </div>
                <div class="ogp-summary">
                  <h3><%= html_escape(title) %></h3>
                  <p class="description"><%= html_escape(description) %></p>
                  <p class="host"><%= host %></p>
                </div>
              </div>
            </a>
          </div>
        ERUBY
        erb = ERB.new(template)
        erb.result(binding)
      end
    end
  end
end
