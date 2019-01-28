# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Formatter
      def initialize(item)
        @item = item
      end

      def format
        template = <<~ERUBY
          <div class="amazon">
            <a href="<%= @item.link %>}"><img src="<%= @item.image %>" /></a>
            <ul>
              <li><a href="<%= @item.link %>"><%= @item.title %></a></li>
              <% if @item.manufacturer.present? %>
              <li><%= @item.manufacturer %></li>
              <% end %>
              <% if @item.author.present? %>
              <li><%= @item.author %></li>
              <% end %>
              <% if @item.binding.present? %>
              <li><%= @item.binding %></li>
              <% end %>
              <li><a href="<%= @item.link %>"><%= @item.price %></a></li>
            </ul>
          </div>
        ERUBY
        erb = ERB.new(template)
        erb.result(binding)
      end
    end
  end
end
