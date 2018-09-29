# frozen_string_literal: true

require 'open-uri'
require 'fileutils'

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
        doc.xpath('./p').each do |node|
          next if node.children.length > 1
          next unless node.xpath('./a').first&.text&.start_with?('http')
          url = node.xpath('./a').first.text
          escaped_url = CGI.escape(url)
          each_fetcher = EachFetcher.new(url)
          if each_fetcher.fetch
            content = OGElement.find(escaped_url)&.html_safe
            node.replace(content) if content
          end
        end
      end

      def replace
        fetch
        doc.to_s.html_safe
      end

      class EachFetcher
        def initialize(url)
          @url = url
        end

        def fetch
          escaped_url = CGI.escape(@url)
          return true if OGElement.exist?(escaped_url)
          opengraph = OpenGraphReader.fetch(@url)
          element = OGElement.new(
            escaped_url: escaped_url,
            url: opengraph&.og&.url || @url,
            title: opengraph&.og&.title,
            image: opengraph&.og&.image,
            description: opengraph&.og&.description
          )
          element.create
        end
      end

      class OGElement
        CACHE_DIR = "#{Lokka.root}/tmp/ogp"

        class << self
          def find(url)
            return nil unless exist?(url)
            File.open(File.join(CACHE_DIR, url)).read
          end

          def exist?(url)
            path = File.join(CACHE_DIR, url)
            File.exist?(path) && test('M', File.open(path)) > 1.month.ago
          end
        end

        def initialize(escaped_url:, url:, title: nil, image: nil, description: nil)
          @escaped_url = escaped_url
          @url = url
          @host = URI.parse(url).host
          @title = title.presence || title_fallback || url
          @image = image.presence || image_fallback
          @description = (description || description_fallback).to_s.truncate(140)
        end

        def create
          FileUtils.mkdir_p(CACHE_DIR)
          File.open(path, 'w') do |file|
            file.puts html
          end
          true
        end

        def path
          File.join(CACHE_DIR, @escaped_url)
        end

        def doc
          @doc ||= begin
                     response = Faraday.get(@url)
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
          <<~HTML
            <a href="#{@url}" class="ogp-link">
              <div class="fetched-ogp">
                <div class="ogp-image">
                  <img src="#{secure_image}" alt="#{html_escape(@title)}" />
                </div>
                <div class="ogp-summary">
                  <h3>#{html_escape(@title)}</h3>
                  <p class="description">#{html_escape(@description)}</p>
                  <p class="host">#{@host}</p>
                </div>
              </div>
            </a>
          HTML
        end
      end
    end
  end
end
