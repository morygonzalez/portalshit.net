# frozen_string_literal: true

module Lokka
  module PortalshitPatches
    def self.registered(app)
      app.get '/index.atom' do
        @posts = Post.preload(:category, :user).
                   published.
                   page(params[:page] || 1).
                   per(20).
                   order(@site.default_order)
        @posts = apply_continue_reading(@posts)

        content_type 'application/atom+xml', charset: 'utf-8'
        builder :'lokka/index'
      end

      app.get '/sitemap.xml' do
        @categories = Category.includes(:entries).where(entries: { draft: false }).all
        content_type 'application/xml', charset: 'utf-8'
        builder :'plugin/lokka-portalshit_patches/public/lokka/sitemap'
      end

      app.get '/sitemap/categories/:slug' do
        category = Category.get_by_fuzzy_slug(params[:slug]) || halt(404)
        @posts = category.entries.published.
                   includes(:category, :tags, :user).
                   order(@site.default_order)
        @posts = apply_continue_reading(@posts)
        content_type 'application/xml', charset: 'utf-8'
        builder :'plugin/lokka-portalshit_patches/public/lokka/categories/sitemap'
      end
    end
  end
end

class Entry
  def long_description
    content = body.
      gsub(%r{<figcaption>.+?</figcaption>}m, '').
      gsub(/<\/?[^>]*>/, '').
      gsub(/[\t]+/, ' ').
      strip.
      gsub(/[\r\n]/, '')[0..120]
    sprintf '%s...', content
  end

  def images
    body.scan(/<img.+?src="(.+?)".+?>/).flatten
  end

  def cover_image
    images.first || 'https://portalshit.net/theme/portalshit/ogp_image.png'
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
