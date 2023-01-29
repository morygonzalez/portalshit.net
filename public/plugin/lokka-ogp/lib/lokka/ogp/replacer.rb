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
            ogp_host = Lokka.production? ? 'https://portalshit.net' : nil
            Parallel.each(doc.xpath('./p'), in_threads: 3) do |node|
              next if node.children.length > 1
              next if node.inner_html =~ %r|img src|
              next if node.inner_html !~ %r|\A<a href.+?/a>\Z|
              url = node.xpath('./a').first.attributes["href"].value
              next if url.blank?
              iframe = <<~HTML
                <iframe
                  src="#{ogp_host}/ogp?url=#{url}"
                  referrerpolicy="origin"
                  style="display: block; width: 100%; height: 125px; max-width: 550px; margin: 1.5em 0px; overflow-y: hidden; border: 0;">
                </iframe>
              HTML
              node.replace(iframe)
            end
            doc.to_s.html_safe
          end
      end
    end
  end
end
