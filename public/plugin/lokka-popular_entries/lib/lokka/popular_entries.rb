# frozen_string_literal: true
require 'open-uri'
require 'nokogiri'

module Lokka
  module PopularEntries
    def self.registerd(app); end
  end
end

class Entry
  attr_accessor :bookmark_count, :bookmark_url

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
      access_ranking.each_with_index do |line, index|
        _, path = *line.split(' ')
        next unless Lokka::PermalinkHelper.custom_permalink_parse(path)
        slug = path.split('/')[-1]
        slugs[index] = slug
        break if slugs.length == limit + buffer
      end
      entries = includes(:category, :tags).
        published.
        where(slug: slugs.values).
        where('entries.created_at < ?', before)
      entries.sort_by {|entry| slugs.values.index(entry.slug) }[0...limit]
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

      house_bookmark_old = slugs.delete('thought-on-own-house')
      house_bookmark_new = slugs['thoughts-on-own-house']
      if house_bookmark_old && house_bookmark_new
        house_bookmark_count = house_bookmark_old[:bookmark_count] + house_bookmark_new[:bookmark_count]
        slugs['thoughts-on-own-house'][:bookmark_count] = house_bookmark_count
      end

      slugs.sort_by {|_, item| item[:bookmark_count] }.reverse.to_h
    end
  end
end
