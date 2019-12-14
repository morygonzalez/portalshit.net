# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class HtmlFormatter
      include CacheControllable

      def initialize(item_id)
        @item_id = item_id
        @kind = :html
        wirite_or_touch_cache unless cache_alive?
      end

      def item
        @item ||= Lokka::AmazonAssociate::Item.new(@item_id)
      end

      def format
        template = <<~ERUBY
          <div class="amazon">
            <div class="amazon-image">
              <a href="<%= item.link %>}"><img src="<%= item.image %>" /></a>
            </div>
            <div class="amazon-content">
              <ul>
                <li><a href="<%= item.link %>"><%= item.title %></a></li>
                <% if item.manufacturer.present? %>
                <li><%= item.manufacturer %></li>
                <% end %>
                <% if item.author.present? %>
                <li><%= item.author %></li>
                <% end %>
                <% if item.binding.present? %>
                <li><%= item.binding %></li>
                <% end %>
                <li><a href="<%= item.link %>"><%= item.price %></a></li>
              </ul>
            </div>
          </div>
        ERUBY
        erb = ERB.new(template)
        erb.result(binding)
      end

      def result
        format
      end
    end
  end
end
