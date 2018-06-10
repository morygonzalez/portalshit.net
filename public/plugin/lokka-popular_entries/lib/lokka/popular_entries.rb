# frozen_string_literal: true

module Lokka
  module PopularEntries
    def self.registerd(app); end
  end
end

class Entry
  attr_accessor :bookmark_count, :bookmark_url

  class << self
    def popular(limit = 5)
      access_ranking = File.open(File.join(Lokka.root, 'public', 'access-ranking.txt'))
      slugs = {}
      access_ranking.each.with_index(1) do |line, index|
        access_limit, path = *line.split(' ')
        slug = path.split('/')[-1]
        slugs[access_limit] = slug
        break if index == limit
      end
      all(slug: slugs.values, limit: limit).sort_by {|entry| slugs.values.index(entry.slug) }
    rescue StandardError
      []
    end

    def hotentry(limit = 5)
      require 'open-uri'
      require 'nokogiri'

      max = limit - 1
      url = 'http://b.hatena.ne.jp/entrylist?sort=count&url=portalshit.net&mode=rss'
      ua = 'AppleWebKit/604.5.6 (KHTML, like Gecko) Reeder/3.1.2 Safari/604.5.6'
      content = open(url, 'User-Agent' => ua).read
      parsed = Hash.from_xml(content)
      slugs = parsed['RDF']['item'][0..max].each_with_object({}) do |item, result|
        link = item['link']
        entry_path = link.sub(%r{http://}, '/entry/').sub(%r{https://}, '/entry/s/')
        slug = link.gsub(%r{https?://(www\.)?portalshit\.net/(\d{4}/\d{2}/\d{2}/|article\.php\?id=)}, '')
        bookmark_count = item['bookmarkcount']
        bookmark_url = "http://b.hatena.ne.jp#{entry_path}"
        result[slug] = { bookmark_count: bookmark_count, bookmark_url: bookmark_url }
      end
      entries = all(slug: slugs.keys, limit: limit).sort_by {|entry| slugs.keys.index(entry.slug) }
      entries.map do |entry|
        entry.bookmark_count = slugs[entry.slug][:bookmark_count]
        entry.bookmark_url = slugs[entry.slug][:bookmark_url]
        entry
      end
    rescue StandardError
      []
    end
  end
end
