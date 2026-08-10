# frozen_string_literal: true

require 'parallel'

module Lokka
  module OGP
    class Replacer
      def initialize(body)
        @body = body
      end

      def doc
        @doc ||= Nokogiri::HTML.fragment(@body.encode('UTF-8', invalid: :replace, undef: :replace, replace: ''))
      end

      def replace
        @replaced ||=
          begin
            Parallel.each(doc.xpath('./p'), in_threads: 3) do |node|
              next if node.children.length > 1
              next if node.inner_html =~ %r{img src|video src}
              next if node.inner_html !~ %r|\A<a href.+?/a>\Z|
              url = node.xpath('./a').first.attributes["href"].value
              next if url.blank?
              fetcher = Lokka::OGP::Fetcher.new(url)
              html = fetcher.cached_html
              node.replace(html)
            end
            doc.to_s.html_safe
          end
      end
    end
  end
end
