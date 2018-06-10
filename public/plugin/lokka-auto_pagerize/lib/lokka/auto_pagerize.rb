# frozen_string_literal: true

module Lokka
  module AutoPagerize
    def self.registered(app); end
  end
end

module DataMapper
  class Pager
    private

      def link_to(page, contents = nil, rel = {})
        %(<a href="#{uri_for(page)}" rel="#{rel[:rel]}">#{contents || page}</a>).html_safe
      end

      def previous_link
        li 'previous jump', link_to(previous_page, option(:previous_text), rel: 'prev') if previous_page
      end

      def next_link
        li 'next jump', link_to(next_page, option(:next_text), rel: 'next') if next_page
      end
  end
end
