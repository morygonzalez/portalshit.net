# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class HtmlFormatter
      include CacheControllable

      attr_reader :item_id

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
          <!DOCTYPE html>
          <html lang="ja">
            <head>
              <title><%= item.title %></title>
              <style>
                .amazon {
                  display: flex;
                  margin: 1em auto;
                  max-height: 320px;
                  background: #fff;
                  border-radius: 4px;
                  color: #000;
                }
                .amazon a {
                  text-shadow: none;
                }
                .amazon-image {
                  flex-grow: 1;
                  width: 300px;
                  margin: 1em auto;
                  display: flex;
                  justify-content: center;
                }
                .amazon-image img {
                  border-radius: 4px;
                  max-height: 280px;
                  max-width: 280px;
                }
                .amazon-content {
                  margin: 1em auto;
                  flex-grow: 4;
                }
                .amazon-content ul {
                  margin-top: 0;
                  list-style: disc;
                }
                @media screen and (max-width:640px) {
                  .amazon-content, .amazon-image {
                    float: none;
                    max-width: 50%;
                  }
                  .amazon-image img {
                    border-radius: 4px;
                    max-height: 150px;
                    max-width: 150px;
                  }
                }
              </style>
            </head>
            <body>
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
            </body>
          </html>
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
