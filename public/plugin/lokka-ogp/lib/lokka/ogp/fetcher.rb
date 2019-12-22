# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'faraday_middleware'
require 'parallel'

module Lokka
  module OGP
    class Fetcher
      def initialize(body)
        @body = body
      end

      def doc
        @doc ||= Nokogiri::HTML.fragment(@body)
      end

      def fetch
        Parallel.each(doc.xpath('./p'), in_threads: 3) do |node|
          next if node.children.length > 1
          next if node.inner_html =~ %r|img src|
          next if node.inner_html !~ %r|\A<a href.+?/a>\Z|
          url = node.xpath('./a').first.attributes["href"].value
          next if url.blank?
          each_fetcher = EachFetcher.new(url)
          element = each_fetcher.element
            iframe = <<~HTML
              <iframe
                src="/ogp/#{element.uname}" title="#{element.title}" scrolling="no" frameborder="0"
                style="display: block; width: 100%; height: 140px; max-width: 800px; margin: 10px 0px;">
              </iframe>
            HTML
            node.replace(iframe) if element.exist?
        end
      end

      def replace
        @replaced ||= begin
                        fetch
                        doc.to_s.html_safe
                      end
      end

      class EachFetcher
        attr_reader :url

        def initialize(url)
          @url = url
        end

        def fetch
          return true if element.exist?
          element.create
        rescue URI::InvalidURIError => e
          puts e.message
        end

        def opengraph
          @opengraph ||= OpenGraphReader.fetch(URI.encode(url))
        end

        def element
          @element ||= OGElement.new(
            url: url,
            title: opengraph&.og&.title,
            image: opengraph&.og&.image,
            description: opengraph&.og&.description
          )
        end
      end

      class OGElement
        CACHE_DIR = "#{Lokka.root}/tmp/ogp"

        attr_reader :url, :title, :image, :description

        def initialize(url:, title: nil, image: nil, description: nil)
          @url = url
          @host = URI.parse(url).host
          @title = title.presence || title_fallback || url
          @image = image.presence || image_fallback
          @description = (description || description_fallback).to_s
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
          @uname ||= OpenSSL::Digest::MD5.new(@url).hexdigest
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
          doc&.xpath('//head/meta[@property="og:image"]')&.first.try(:[], 'content') || '/plugin/lokka-ogp/assets/no-image.png'
        end

        def description_fallback
          doc&.xpath('//head/meta[@name="description"]')&.first.try(:[], 'content')
        end

        def secure_image
          if use_proxy?
            "/imageproxy/120/#{@image}"
          else
            @image
          end
        end

        def use_proxy?
          exclude_regexp = /(githubusercontent|=\d|token=\w+)/
          Lokka.production? && @image.to_s.start_with?('http') && !@image.to_s.match(exclude_regexp)
        end

        def html
          template = <<~ERUBY
            <!DOCTYPE html>
            <html lang="ja">
              <head>
                <title><%= @title %></title>
                <style>
                  body {
                    margin: 0;
                  }

                  a.ogp-link {
                    display:block
                  }

                  a.ogp-link:link,
                  a.ogp-link:hover {
                    color:#a3a3a2
                  }

                  a.ogp-link .fetched-ogp {
                    border-radius: 5px;
                    -moz-border-radius: 5px;
                    -webkit-border-radius: 5px;
                    border: 1px solid #333;
                    font-size: .9em;
                    height: 120px;
                    display: flex;
                    justify-content: space-between;
                    overflow:hidden
                  }

                  a.ogp-link .fetched-ogp:hover {
                    background:#212121
                  }

                  a.ogp-link .fetched-ogp .ogp-image {
                    max-width: 120px;
                    flex-grow: 1;
                    background-color:#fffffc
                  }

                  a.ogp-link .fetched-ogp .ogp-image img {
                    min-height: 120px;
                    max-width: 120px;
                    object-fit:cover
                  }

                  a.ogp-link .fetched-ogp .ogp-summary {
                    flex-grow: 3;
                    padding: .2em 1.5em;
                    display: flex;
                    flex-direction: column;
                    justify-content:space-between
                  }

                  a.ogp-link .fetched-ogp .ogp-summary h3 {
                    margin:0 0 .3em
                    text-overflow: ellipsis;
                    max-width: 680px;
                  }

                  a.ogp-link .fetched-ogp .ogp-summary h3:link,
                  a.ogp-link .fetched-ogp .ogp-summary h3:visited {
                    color:#e8ecef
                  }

                  a.ogp-link .fetched-ogp .ogp-summary h3::before {
                    content:none
                  }

                  a.ogp-link .fetched-ogp .ogp-summary .description {
                    max-width: 680px;
                    font-size: 0.9em;
                    line-height: 1.5em;
                    margin: .5em auto .5em 0;
                    white-space: nowrap;
                    text-overflow: ellipsis;
                    overflow:hidden
                  }

                  a.ogp-link .fetched-ogp .ogp-summary .host {
                    margin:.3em 0
                  }
                </style>
              </head>
              <body>
                <div class="ogp">
                  <a href="<%= @url %>" class="ogp-link">
                  <div class="fetched-ogp">
                    <div class="ogp-image">
                      <img src="<%= secure_image %>" alt="<%= html_escape(@title) %>" />
                    </div>
                    <div class="ogp-summary">
                      <h3><%= html_escape(@title) %></h3>
                      <p class="description"><%= html_escape(@description) %></p>
                      <p class="host"><%= @host %></p>
                    </div>
                  </div>
                  </a>
                </div>
              </body>
            </html>
          ERUBY
          erb = ERB.new(template)
          erb.result(binding)
        end
      end
    end
  end
end
