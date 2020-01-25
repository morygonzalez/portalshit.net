# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'faraday_middleware'

module Lokka
  module OGP
    class Element
      CACHE_DIR = "#{Lokka.root}/tmp/ogp"

      attr_reader :url

      def initialize(url)
        @url = url
      end

      def host
        @host ||= URI.parse(url).host
      end

      def title
        @title ||= opengraph&.og&.title.presence || title_fallback || url
      end

      def image
        @image ||= opengraph&.og&.image.presence || image_fallback
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
        @opengraph ||= OpenGraphReader.fetch(URI.encode(url))
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
                   response = connection.get(URI.encode(@url))
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
        fallback_og_image_url = '/plugin/lokka-ogp/assets/no-image.png'
        return og_image_url if og_image_url =~ /^https?:\/\//
        return URI.parse(url).scheme + ':' + host + og_image_url if og_image_url =~ /^\//
        fallback_og_image_url
      end

      def description_fallback
        doc&.xpath('//head/meta[@name="description"]')&.first.try(:[], 'content')&.to_s
      end

      def secure_image
        if use_proxy?
          "/imageproxy/120/#{image}"
        else
          image
        end
      end

      def use_proxy?
        exclude_regexp = /(githubusercontent|=\d|token=\w+)/
        Lokka.production? && image.to_s.start_with?('http') && !image.to_s.match(exclude_regexp)
      end

      def html
        template = <<~ERUBY
          <!DOCTYPE html>
          <html lang="ja">
            <head>
              <title><%= title %></title>
              <style>
                body {
                  margin: 0;
                }

                a.ogp-link, a.ogp-link:link {
                  color: #a3a3a2;
                  background: #fffffc;
                  text-decoration: none;
                }

                a.ogp-link:hover {
                  color: #a3a3a2;
                  background: #212121;
                }

                .ogp {
                  display: flex;
                  justify-content: space-between;
                  border-radius: 5px;
                  border: 1px solid #333;
                  font-size: .9em;
                  height: 120px;
                }

                .ogp-image {
                  max-width: 120px;
                  flex-grow: 1;
                  background-color: #fffffc;
                  border-radius: 5px 0 0 5px;
                }

                .ogp-image img {
                  border-radius: 5px 0 0 5px;
                  min-height: 120px;
                  max-width: 120px;
                  object-fit: cover;
                }

                .ogp-summary {
                  flex-grow: 3;
                  padding: .2em 1.5em;
                  display: flex;
                  border-radius: 0 5px 5px 0;
                  flex-direction: column;
                  justify-content: space-between;
                  background: #fffffc;
                  overflow: hidden;
                }

                .ogp-link:hover .ogp-summary {
                  color: #a3a3a2;
                  background: #212121;
                }

                .ogp-summary h3 {
                  margin:0 0 .3em;
                  text-overflow: ellipsis;
                  max-width: 630px;
                }

                .ogp-summary h3:link, .ogp-summary h3:visited {
                  color: #e8ecef;
                }

                .description {
                  max-width: 630px;
                  font-size: 0.9em;
                  line-height: 1.5em;
                  margin: .5em auto .5em 0;
                  border-radius: 0 5px 5px 0;
                }

                .host {
                  margin: .3em 0;
                }

                @media screen and (max-width:640px) {
                  .ogp {
                    font-size: 80%;
                  }
                  .description, .ogp-summary h3 {
                    float: none;
                  }
                }
              </style>
            </head>
            <body>
              <a href="<%= url %>" class="ogp-link" target="_parent">
                <div class="ogp">
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
            </body>
          </html>
        ERUBY
        erb = ERB.new(template)
        erb.result(binding)
      end
    end
  end
end
