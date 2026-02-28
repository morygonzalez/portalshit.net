# frozen_string_literal: true

require_relative 'portalshit_patches/app'
require_relative 'portalshit_patches/helpers'
require_relative 'portalshit_patches/search'
require_relative 'portalshit_patches/popular_keywords'

module Lokka
  module PortalshitPatches
    def self.registered(app); end
  end
end

class Entry
  def toc
    @toc ||=
      Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new(nesting_level: 2..4)).
      render(raw_body).html_safe
  end

  alias original_long_body body
  def long_body_with_figure
    @long_body_with_figure ||=
      begin
        doc = Nokogiri::HTML.fragment(original_long_body)
        doc.css('img:root, p:root > img').each do |img|
          caption = img.remove_attribute('title')
          erb = ERB.new <<~ERUBY
            <figure>
              #{img}
              <% if caption.present? %>
              <figcaption>#{caption}</figcaption>
              <% end %>
            </figure>
          ERUBY
          figure = Nokogiri::HTML.fragment(erb.result(binding))
          parent = img.parent
          if parent.name == 'p' && parent.children.length == 1
            parent.replace(figure)
          else
            img.replace(figure)
          end
        end
        doc.to_s
      end
  end
  alias body long_body_with_figure

  def long_description(limit = 120)
    content = body.
      gsub(%r{<figcaption>.*?</figcaption>}m, '').
      gsub(/<\/?[^>]*>/, '').
      gsub(/[\t]+/, ' ').
      strip.
      gsub(/[\r\n]/, '')[0..limit]
    sprintf '%s...', content
  end

  def body_with_toc
    return body if toc.blank?
    body.sub(/<!-- ?toc ?-->/, "<h3>Table of Contents</h3>\n#{toc}").html_safe
  end

  def images
    doc = Nokogiri::HTML.fragment(body)
    doc.css('img:root, figure:root > img, p:root > video, p:root img, .pswp-gallery__item > a > img').map {|item|
      case item.name
      when "img"
        item.attributes["src"].value
      when "video"
        item.attributes["poster"]&.value
      end
    }
  end

  def cover_image
    if images.first && images.first.end_with?('jpg', 'JPG', 'jpeg', 'JPEG', 'png', 'PNG', 'gif', 'GIF')
      images.first
    else
      'https://portalshit.net/theme/portalshit/ogp_image.png'
    end
  end
end

class Comment
  after_create :send_notification_to_entry_author

  private

  def send_notification_to_entry_author
    return if Lokka.test?
    return if email == entry.user.email
    return if status == SPAM

    credentials = Aws::Credentials.new(Option.aws_access_key_id, Option.aws_secret_access_key)
    region = 'us-east-1'
    client = Aws::SESV2::Client.new(credentials: credentials, region: region)
    client.send_email(notification_params)
  end

  def notification_params
    from = 'portal shit! <info@portalshit.net>'
    to = entry.user.email
    subject_data = %Q(#{name} commented on your entry "#{entry.title}")
    subject_data = "[#{Lokka.env}] #{subject_data}" unless Lokka.production?
    body_data = <<~TEXT
      You have received comment from #{name} on "#{entry.title}", at #{created_at}

      #{body.lines.map {|line| "> #{line}" }.join("\n")}

      See full conversation https://portalshit.net#{link}
    TEXT
    {
      from_email_address: from,
      destination: { to_addresses: [to] },
      content: {
        simple: {
          subject: {
            data: subject_data
          },
          body: {
            text: {
              data: body_data
            },
            html: {
              data: Markup.use_engine('redcarpet', body_data)
            }
          }
        }
      }
    }
  end
end
