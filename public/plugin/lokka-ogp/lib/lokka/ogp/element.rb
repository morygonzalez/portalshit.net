# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'tempfile'
require 'faraday_middleware'
require 'addressable'

module Lokka
  module OGP
    class Element
      include Card

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
        case
        when wikipedia?
          parsed = URI.parse(Addressable::URI.escape(@url))
          title = @url.split('/').last
          %(#{parsed.scheme}://#{parsed.hostname}/w/index.php?title=#{title})
        when youtube?
          %(https://www.youtube.com/oembed?url=#{Addressable::URI.escape(@url)})
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
        content = html
        Tempfile.create(['ogp-', '.tmp'], CACHE_DIR) do |file|
          file.write(content)
          file.flush
          file.fsync
          File.rename(file.path, cache_path)
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

      def youtube?
        host =~ /youtube/
      end

      def wikipedia?
        @url =~ /wikipedia\.org/
      end

      def doc
        @doc ||= begin
                   response = connection.get(url_to_request)
                   Nokogiri::HTML(response.body)
                 rescue StandardError
                   nil
                 end
      end

      def oembed_result
        response = connection.get(url_to_request)
        JSON.parse(response.body)
      end

      # SafeUrlMiddleware を follow_redirects より下に積むことで、リダイレクト
      # 先の URL も 1 ホップごとに検証される。外部ホストから 127.0.0.1 へ 302
      # させる SSRF の回避策を塞ぐため、順番を入れ替えないこと。
      def connection
        @connection ||= Faraday.new(request: { open_timeout: 5, timeout: 5 }) do |builder|
          builder.response :follow_redirects
          builder.use SafeUrlMiddleware
          builder.adapter Faraday.default_adapter
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

      def html
        return card_html unless youtube?

        template = <<~ERUBY
          <div class="iframe-container youtube">
            <%= oembed_result['html'] %>
          </div>
        ERUBY
        ERB.new(template).result(binding)
      end
    end
  end
end
