# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'

module Lokka
  module PopularEntries
    def self.registered(app)
      app.get '/popular' do
        @theme_types << :entries
        @page_title = t('popular_entries')
        @page_description = 'よく読まれている記事。'
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})

        today = Post.includes(:category, :tags).popular(target: 'today', limit: 4)
        yesterday = Post.includes(:category, :tags).popular(target: 'yesterday', limit: 4)
        recent = Post.includes(:category, :tags).popular(target: 'all', limit: 4)
        hatena = Post.includes(:category, :tags).hotentry(limit: 4)

        @popular_entries = {
          today: today,
          yesterday: yesterday,
          recent: recent,
          'hatena-bookmark': hatena
        }

        haml :"plugin/lokka-popular_entries/views/index", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/popular/today' do
        @theme_types << :entries
        @page_title = t('popular_entries_today')
        @page_description = %(今日（#{l(Date.today, format: :long)}）アクセス数が多い記事の一覧です。)
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: t('popular_entries'), link: '/popular' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})
        @entries = Post.includes(:category, :tags).popular(target: 'today', limit: 25)
        haml :"plugin/lokka-popular_entries/views/show", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/popular/yesterday' do
        @theme_types << :entries
        @page_title = t('popular_entries_yesterday')
        @page_description = %(昨日（#{l(Date.yesterday, format: :long)}）アクセス数が多かった記事の一覧です。)
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: t('popular_entries'), link: '/popular' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})
        @entries = Post.includes(:category, :tags).popular(target: 'yesterday', limit: 25)
        haml :"plugin/lokka-popular_entries/views/show", layout: :"theme/#{@theme.name}/layout"
      end

      app.get %r{/popular/(\d{4}\-\d{2}\-\d{2})} do |date|
        @theme_types << :entries
        @page_title = t('popular_entries_on', date: l(Date.parse(date), format: :short))
        @page_description = %(#{l(Date.parse(date), format: :long)}にアクセス数が多かった記事の一覧です。)
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: t('popular_entries'), link: '/popular' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})
        @entries = Post.includes(:category, :tags).popular(target: date, limit: 25)
        @date = date
        haml :"plugin/lokka-popular_entries/views/show", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/popular/recent' do
        @theme_types << :entries
        @page_title = t('popular_entries_recent')
        @page_description = '直近 30 日間でアクセス数が多かった記事の一覧です。'
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: t('popular_entries'), link: '/popular' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})
        @entries = Post.includes(:category, :tags).popular(target: 'all', limit: 25)
        haml :"plugin/lokka-popular_entries/views/show", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/popular/hatena-bookmark' do
        @theme_types << :entries
        @page_title = t('popular_entries_hatena-bookmark')
        @page_description = 'はてなブックマークでブックマーク数が多い記事の一覧です。'
        @bread_crumbs = [{ name: t('home'), link: '/' },
                         { name: t('popular_entries'), link: '/popular' },
                         { name: @page_title }]
        @title = %Q(#{@page_title} - #{@site.title})
        @entries = Post.includes(:category, :tags).hotentry(limit: 25)
        haml :"plugin/lokka-popular_entries/views/show", layout: :"theme/#{@theme.name}/layout"
      end
    end
  end
end

class Entry
  attr_accessor :bookmark_count, :bookmark_url, :pv

  class << self
    def popular(limit: 5, target: 'all')
      case target
      when 'all', 'today', 'yesterday'
        path = File.join(
          Lokka.root,
          "public/log-aggregation/access-ranking-#{target}.txt"
        )
        access_ranking = File.open(path)
        before = if target == 'yesterday'
                   Date.yesterday.end_of_day
                 else
                   Date.today.end_of_day
                 end
      when /\d{4}-\d{2}-\d{2}/
        target_date = Date.parse(target)
        access_ranking = if target_date < Date.new(2022, 6, 13) || target_date > Date.yesterday
                           nil
                         else
                           url = "https://s3.ap-northeast-1.amazonaws.com/backup.portalshit.net/log/access-ranking-#{target}.txt"
                           OpenURI.open_uri(url) rescue nil
                         end
        before = target_date
      else
        access_ranking = nil
      end

      raise Sinatra::NotFound unless access_ranking

      buffer = 2
      slugs = {}
      access_ranking.each do |line|
        pv, path = *line.split(' ')
        next unless Lokka::PermalinkHelper.custom_permalink_parse(path)
        slug = path.split('/')[-1]
        slugs[slug] = pv
        break if slugs.length == limit + buffer
      end
      entries = includes(:category, :tags).
        published.
        where(slug: slugs.keys).
        where('entries.created_at < ?', before)
      entries.map {|entry|
        entry.pv = slugs[entry.slug]
        entry
      }.sort_by {|entry| -entry.pv.to_i }[0...limit]
    end

    def hotentry(limit: 5)
      dir = File.expand_path('tmp/popular_entries')
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      cache_path = File.join(dir, "hatena-bookmark.cache")
      cache_file = File.open(cache_path, 'w+')
      cached_content = cache_file.read

      if File.mtime(cache_path) > Time.now - 1.hour && cached_content.present?
        slugs = Marshal.load(cached_content)
      else
        slugs = retrieve_bookmarks
        Marshal.dump(slugs, cache_file)
      end

      cache_file.close

      entries = includes(:category, :tags).published.where(slug: slugs.keys)
      entries = entries.sort_by {|entry| slugs.keys.index(entry.slug) }
      entries.map do |entry|
        entry.bookmark_count = slugs[entry.slug][:bookmark_count]
        entry.bookmark_url = slugs[entry.slug][:bookmark_url]
        entry
      end
      entries[0...limit]
    end

    def retrieve_bookmarks
      ua = 'AppleWebKit/604.5.6 (KHTML, like Gecko) Reeder/3.1.2 Safari/604.5.6'
      url = 'https://b.hatena.ne.jp/site/portalshit.net/?sort=count&mode=rss'
      content = URI.open(url, 'User-Agent' => ua).read
      parsed = Hash.from_xml(content)

      slugs = parsed['RDF']['item'].each_with_object({}) do |item, result|
        link = item['link']
        entry_path = link.sub(%r{http://}, '/entry/').sub(%r{https://}, '/entry/s/')
        slug = link.
          gsub(%r{https?://portalshit\.net/(\d{4}/\d{2}/\d{2}/|article\.php\?id=)?}, '')
        bookmark_count = item['bookmarkcount']
        bookmark_url = "https://b.hatena.ne.jp#{entry_path}"
        result[slug] = { bookmark_count: bookmark_count.to_i, bookmark_url: bookmark_url }
      end

      slug_redirects = {
        'thought-on-own-house' => 'thoughts-on-own-house',
        'internet-is-becomming-inconvenient' => 'internet-becomes-inconvenient'
      }
      slug_redirects.each do |old_slug, new_slug|
        old_bookmark = slugs.delete(old_slug)
        next unless old_bookmark

        if slugs[new_slug]
          slugs[new_slug][:bookmark_count] += old_bookmark[:bookmark_count]
        else
          slugs[new_slug] = old_bookmark
        end
      end

      slugs.sort_by {|_, item| item[:bookmark_count] }.reverse.to_h
    end
  end
end
