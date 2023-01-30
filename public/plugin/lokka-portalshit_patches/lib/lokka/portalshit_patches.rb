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
        builder :'plugin/lokka-portalshit_patches/public/lokka/index'
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

      app.get '/search.json' do
        return if params[:query].blank?
        smart_query = search_index.smart_query(
          %i[title title_tokenized body category category_tokenized tags],
          params[:query]
        )
        search_result = search_index.search(smart_query, limit: 10000)[0..10]
        posts = Post.published.joins(:category).where(id: search_result).
          sort_by {|post| search_result.index(post.id.to_s) }
        posts_hash = posts.each_with_object([]) {|post, result|
          result << {
            id: post.id,
            title: post.title,
            link: post.link,
            created_at: post.created_at
          }
        }
        cache_control :public, :must_revalidate, max_age: 5.minutes
        content_type :json
        posts_hash.to_json
      end
    end
  end

  class App
    configure do
      bg_images = YAML.load_file(File.join(File.dirname(__FILE__), '../../', 'config.yml'))['header_bg']
      set :header_bg_params, -> {
        dark_image = bg_images['dark'].sample
        light_image = bg_images['light'].sample
        {
          'data-bg-dark-image': "dark-#{dark_image['name']}",
          'data-bg-dark-description': dark_image['description'],
          'data-bg-light-image': "light-#{light_image['name']}",
          'data-bg-light-description': light_image['description']
        }
      }
    end

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
      entries = Entry.includes(:category, :user, :tags, :approved_comments).where(id: entry_ids)
      @entries_group_by_category = entries.each_with_object({}) {|entry, result|
        result[entry.category] ||= []
        result[entry.category] << entry
      }

      @title = %Q(#{t('categories')} - #{@site.title})

      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: t('categories') }]

      render_detect :categories
    end

    get '/popular/today' do
      @theme_types << :entries
      @page_title = '今日よく読まれている記事'
      @page_description = %(今日（ #{Date.today} ）アクセス数が多い記事の一覧です。)
      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: @page_title }]
      @entries = Post.includes(:category, :tags).popular(target: 'today', limit: 25)
      render_detect :popular_entries
    end

    get '/popular/yesterday' do
      @theme_types << :entries
      @page_title = '昨日よく読まれた記事'
      @page_description = %(昨日（ #{Date.yesterday} ）アクセス数が多かった記事の一覧です。)
      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: @page_title }]
      @entries = Post.includes(:category, :tags).popular(target: 'yesterday', limit: 25)
      render_detect :popular_entries
    end

    get %r{^/popular/(\d{4}\-\d{2}\-\d{2})$} do |date|
      @theme_types << :entries
      @page_title = 'その日よく読まれた記事'
      @page_description = %(#{Date.parse(date)} にアクセス数が多かった記事の一覧です。)
      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: @page_title }]
      @entries = Post.includes(:category, :tags).popular(target: date, limit: 25)
      render_detect :popular_entries
    end

    get '/popular/recent' do
      @theme_types << :entries
      @page_title = '最近よく読まれている記事'
      @page_description = '直近 30 日間でアクセス数が多かった記事の一覧です。'
      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: @page_title }]
      @entries = Post.includes(:category, :tags).popular(target: 'all', limit: 25)
      render_detect :popular_entries
    end

    get '/popular/hatena-bookmark' do
      @theme_types << :entries
      @page_title = 'はてなブックマークで注目を集めた記事'
      @page_description = 'はてなブックマークでブックマーク数が多い記事の一覧です。'
      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: @page_title }]
      @entries = Post.includes(:category, :tags).hotentry(limit: 25)
      render_detect :popular_entries
    end
  end

  module Helpers
    def sorted_categories
      @categories ||= Category.find(
        Category.joins(:entries).where(entries: Post.published).
          group(:id).order(count_entries_id: :desc).count(:'entries.id').
          keys
      )
    end

    def bread_crumb
      bread_crumb =
        @bread_crumbs[0..-2].each.with_index(1).
        inject('<ol itemscope itemtype="http://schema.org/BreadcrumbList">') do |html, (bread, index)|
          html += <<~RUBY_HTML
                      <li itemprop="itemListElement" itemscope itemtype="http://schema.org/ListItem">
                        <a itemscope itemtype="http://schema.org/Thing" itemprop="item" href="#{bread[:link]}" id="#{bread[:link]}">
                          <span itemprop="name">#{bread[:name]}</span>
                        </a>
                        <meta itemprop="position" content="#{index}" />
                      </li>
          RUBY_HTML
        end + <<~RUBY_HTML
            <li itemprop="itemListElement" itemscope itemtype="http://schema.org/ListItem">
              <span itemscope itemtype="http://schema.org/Thing" itemprop="item" id="#{@bread_crumbs[-1][:link]}">
                <span itemprop="name">#{h(@bread_crumbs[-1][:name])}</span>
              </span>
              <meta itemprop="position" content="#{@bread_crumbs.length}" />
            </li>
          </ol>
        RUBY_HTML
        bread_crumb.html_safe
    end

    def color_mode
      request.cookies['prefers-color-scheme']
    end

    def portalshit_manifest
      @portalshit_manifest ||= \
        begin
          file_path = File.join(Lokka.root, 'public/theme/portalshit/scripts', 'manifest.json')
          content = File.open(file_path).read
          manifest = JSON.parse(content)
        end
    end

    def portalshit_javascript_path(file_name)
      "#{@theme.path}/scripts/#{portalshit_manifest[file_name]}"
    end

    def not_found_candidates
      @not_found_candidates ||=
        begin
          slugs = Entry.published.where.not('slug REGEXP ?', '^[0-9]+$').pluck(:slug)
          spell_checker = DidYouMean::SpellChecker.new(dictionary: slugs)
          current_slug = request.path_info.split('/').last
          slug_candidate = spell_checker.correct(current_slug)
          Entry.published.where(slug: slug_candidate)
        end
    end
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
          img.replace(figure)
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
    body.scan(/(?:<img.+?src(?:\s)*="(.+?)".+?>|<video.+?poster(?:\s)*="(.+?)".+>)/m).flatten.compact
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

