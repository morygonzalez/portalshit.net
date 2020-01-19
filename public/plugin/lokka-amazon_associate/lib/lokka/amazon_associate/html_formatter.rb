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
        @item ||= Item.new(@item_id)
      end

      def format
        template = <<~HTML
          <!DOCTYPE html>
          <html lang="ja">
            <head>
              <title><%= item.title %></title>
              <style>
                .amazon {
                  display: flex;
                  margin: 2em auto;
                  max-height: 320px;
                  background: #fff;
                  color: #000;
                }
                .amazon a {
                  text-shadow: none;
                }
                .amazon-image {
                  display: flex;
                  align-items: center;
                  flex-grow: 1;
                  max-width: 300px;
                  margin: 1em auto;
                  justify-content: center;
                }
                .amazon-image img {
                  max-height: 280px;
                  max-width: 280px;
                  filter: brightness(100%);
                }
                .amazon-image img:hover {
                  filter: brightness(105%);
                }
                .amazon-content {
                  margin-left: 2em;
                  flex-grow: 4;
                }
                .amazon-content ul {
                  margin: 0 auto;
                  list-style: disc;
                  padding-left: 1em;
                }
                .amazon-content .to-amazon a {
                  display: block;
                  width: 328px;
                  height: 52px;
                  background: url("https://images-fe.ssl-images-amazon.com/images/G/09/associates/buttons/assocbtn_orange_amazon4_new.png") no-repeat;
                  background-size: cover;
                  filter: brightness(100%);
                }
                .amazon-content ul .to-amazon a:hover {
                  filter: brightness(95%);
                  transition: all .3s ease;
                }
                @media screen and (max-width: 640px) {
                  .amazon {
                    font-size: 88%;
                    line-height: 155%;
                  }
                  .amazon-image, .amazon-content {
                    float: none;
                  }
                  .amazon-image {
                    max-width: 40%;
                  }
                  .amazon-image img {
                    max-height: 130px;
                    max-width: 130px;
                  }
                  .amazon-content {
                    max-width: 60%;
                    margin: 0 0 1em;
                  }
                  div.to-amazon a {
                    width: 152px;
                    height: 24px;
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
                  <div><a href="<%= item.link %>"><img src="https://images-fe.ssl-images-amazon.com/images/G/09/associates/buttons/assocbtn_orange_amazon4_new.png" width="328" /></a></div>
                </div>
              </div>
            </body>
          </html>
        HTML
        erb = ERB.new(template)
        erb.result(binding)
      end

      def result
        format
      end
    end
  end
end
