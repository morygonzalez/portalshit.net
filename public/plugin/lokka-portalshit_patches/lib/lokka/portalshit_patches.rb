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

  class App
    get '/categories' do
      @theme_types << :entries

      query = <<~SQL
        select entries.id
        from entries
        inner join (
          select
            category_id,
            group_concat(id order by created_at desc) as entry_ids,
            count(id) as entry_count,
            max(created_at) as last_created_at
          from entries
          where entries.draft = false
          group by category_id
        ) as grouped_entries
        on grouped_entries.category_id = entries.category_id and find_in_set(id, entry_ids) between 1 and 4
        inner join categories on categories.id = entries.category_id
        order by last_created_at desc, entries.id desc;
      SQL
      entry_ids = ActiveRecord::Base.connection.select_all(query).rows.flatten
      entries = Entry.includes(:category, :user, :tags, :comments).where(id: entry_ids)
      @entries_group_by_category = entries.each_with_object({}) {|entry, result|
        result[entry.category] ||= []
        result[entry.category] << entry
      }

      @title = %Q(#}{@site.title})

      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: t('categories') }]

      render_detect :categories
    end
  end
end

class Entry
  def long_description(limit = 120)
    content = body.
      gsub(%r{<figcaption>.+?</figcaption>}m, '').
      gsub(/<\/?[^>]*>/, '').
      gsub(/[\t]+/, ' ').
      strip.
      gsub(/[\r\n]/, '')[0..limit]
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
