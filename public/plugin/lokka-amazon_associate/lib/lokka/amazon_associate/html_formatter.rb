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
        <<~HTML
          <!DOCTYPE html>
          <html lang="ja">
            <head>
            <title><%= item.title %></title>
            <style>
              .amazon {
                display: flex;
                align-items: start;
                margin: 2em auto;
                max-height: 320px;
                background: #fff;
                color: #000;
                font-size: 16px;
                line-height: 150%;
                border-radius: 5px;
                -moz-border-radius: 5px;
                -webkit-border-radius: 5px;
              }
              .amazon a {
                text-shadow: none;
              }
              .amazon-image, .amazon-content {
                margin: 2.5em 1em;
              }
              .amazon-image {
                display: flex;
                align-items: center;
                flex-grow: 1;
                width: 300px;
                max-width: 300px;
                justify-content: center;
              }
              .amazon-image img {
                filter: brightness(100%);
                max-height: 280px;
                max-width: 280px;
              }
              .amazon-image img:hover {
                filter: brightness(105%);
              }
              .amazon-content {
                flex-grow: 4;
                margin-right: 2em;
                max-width: 60%;
              }
              .amazon-content .item-title {
                font-size: 1.2em;
                font-weight: bold;
                margin: 0 auto;
              }
              .amazon-content .item-title:before {
                content: none;
                margin: 0;
              }
              .amazon-content .item-meta, .amazon-content .item-price {
                margin: .75em auto;
              }
              .amazon-content .item-meta span:not(:last-child):after {
                content: '/';
                margin-left: .5em;
              }
              .amazon-content .to-amazon a {
                display: block;
                width: 328px;
                height: 52px;
                background: url("https://images-fe.ssl-images-amazon.com/images/G/09/associates/buttons/assocbtn_orange_amazon4_new.png") no-repeat;
                background-size: cover;
                filter: brightness(100%);
              }
              .amazon-content .to-amazon a:hover {
                filter: brightness(95%);
                transition: all .3s ease;
              }
              @media screen and (max-width: 640px) {
                .amazon {
                  font-size: 88%;
                  line-height: 155%;
                }
                .amazon-image {
                  max-width: 40%;
                  min-width: 120px;
                  margin: 1em .5em;
                }
                .amazon-image img {
                  max-height: 120px;
                  max-width: 120px;
                }
                .amazon-content {
                  max-width: 60%;
                  margin: 1em 1em 1em 0;
                }
                .amazon-content .item-title {
                  font-size: 1em;
                }
                .amazon-content .item-meta {
                  font-size: .9em;
                }
                .amazon-content .item-title, .amazon-content .item-meta {
                  text-overflow: ellipsis;
                  overflow: hidden;
                  white-space: nowrap;
                }
                .amazon-content .item-meta, .amazon-content .item-price {
                  margin: .25em auto;
                }
                .amazon-content .to-amazon a {
                  width: 152px;
                  height: 24px;
                }
              }
              </style>
            </head>
            <body>
              <div class="amazon">
                <div class="amazon-image">
                  <a class="image" data-product-title="<%= item.title %>" href="<%= item.link %>"><img src="<%= item.image %>" /></a>
                </div>
                <div class="amazon-content">
                  <h4 class="item-title"><a class="title" data-product-title="<%= item.title %>" href="<%= item.link %>"><%= item.title %></a></h1>
                  <div class="item-meta">
                    <% if item.manufacturer.present? %>
                    <span><%= item.manufacturer %></span>
                    <% end %>
                    <% if item.author.present? %>
                    <span><%= item.author %></span>
                    <% end %>
                    <% if item.binding.present? %>
                    <span><%= item.binding %></span>
                    <% end %>
                  </div>
                  <div class="item-price"><a class="price" data-product-title="<%= item.title %>" href="<%= item.link %>"><%= item.price %></a></div>
                  <div class="to-amazon">
                    <a class="button" data-product-title="<%= item.title %>" href="<%= item.link %>"></a>
                  </div>
                </div>
              </div>
            </body>
          </html>
        HTML
      end

      def result
        erb = ERB.new(format)
        erb.result(binding)
      end
    end
  end
end
