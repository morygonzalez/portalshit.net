# frozen_string_literal: true

require 'parallel'

module Lokka
  module OGP
    class Replacer
      def initialize(body)
        @body = body
      end

      def doc
        @doc ||= Nokogiri::HTML.fragment(@body)
      end

      def replace
        @replaced ||=
          begin
            Parallel.each(doc.xpath('./p'), in_threads: 3) do |node|
              next if node.children.length > 1
              next if node.inner_html =~ %r|img src|
              next if node.inner_html !~ %r|\A<a href.+?/a>\Z|
              url = node.xpath('./a').first.attributes["href"].value
              next if url.blank?
              fetcher = Lokka::OGP::Fetcher.new(url)
              if fetcher.fetch
                element = fetcher.element
                path = "#{Lokka.root}/tmp/ogp/#{element.uname}"
                html = File.open(path).read
              end
              node.replace(html)
            end
            doc.to_s.html_safe
          end
      end
    end
  end
end
