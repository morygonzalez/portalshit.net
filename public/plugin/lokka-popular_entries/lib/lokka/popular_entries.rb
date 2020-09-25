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
      access_ranking.each do |line|
        access_limit, path = *line.split(' ')
        next if path =~ %r{^/(category|tags)/}
        slug = path.split('/')[-1]
        slugs[access_limit] = slug
        break if slugs.length == limit
      end
      where(slug: slugs.values).limit(limit).sort_by {|entry| slugs.values.index(entry.slug) }
    rescue StandardError
      []
    end

    def hotentry(limit = 5)
      require 'open-uri'
      require 'nokogiri'

      max = limit - 1
      ua = 'AppleWebKit/604.5.6 (KHTML, like Gecko) Reeder/3.1.2 Safari/604.5.6'

      url = 'https://b.hatena.ne.jp/entrylist?sort=count&url=portalshit.net&mode=rss'
      www_url = 'https://b.hatena.ne.jp/entrylist?sort=count&url=www.portalshit.net&mode=rss'

      content = open(url, 'User-Agent' => ua).read
      www_content = open(www_url, 'User-Agent' => ua).read

      parsed = Hash.from_xml(content)
      www_parsed = Hash.from_xml(www_content)

      slugs = parsed['RDF']['item'][0..max].each_with_object({}) do |item, result|
        link = item['link']
        entry_path = link.sub(%r{http://}, '/entry/').sub(%r{https://}, '/entry/s/')
        slug = link.
                 gsub(%r{https?://portalshit\.net/(\d{4}/\d{2}/\d{2}/|article\.php\?id=)?}, '').
                 sub('thought-on-own-house', 'thoughts-on-own-house')
        bookmark_count = item['bookmarkcount']
        bookmark_url = "https://b.hatena.ne.jp#{entry_path}"
        result[slug] = { bookmark_count: bookmark_count, bookmark_url: bookmark_url }
      end

      www_slugs = www_parsed['RDF']['item'][0..max].each_with_object({}) do |item, result|
        link = item['link']
        entry_path = link.sub(%r{http://}, '/entry/').sub(%r{https://}, '/entry/s/')
        slug = link.gsub(%r{https?://(www\.)?portalshit\.net/(\d{4}/\d{2}/\d{2}/|article\.php\?id=)?}, '')
        bookmark_count = item['bookmarkcount']
        bookmark_url = "https://b.hatena.ne.jp#{entry_path}"
        result[slug] = { bookmark_count: bookmark_count, bookmark_url: bookmark_url }
      end

      www_slugs.each {|key, value|
        if slugs[key]
          slugs[key][:bookmark_count].to_i += www_slugs[key][:bookmark_count].to_i
          www_slugs.delete(key)
        end
      }

      merged_slugs = slugs.merge(www_slugs).sort_by {|_, item| item[:bookmark_count].to_i }
      merged_slugs = merged_slugs.reverse[0..max].to_h

      entries = where(slug: merged_slugs.keys).limit(limit)
      entries = entries.sort_by {|entry| merged_slugs.keys.index(entry.slug) }
      entries.map do |entry|
        entry.bookmark_count = merged_slugs[entry.slug][:bookmark_count]
        entry.bookmark_url = merged_slugs[entry.slug][:bookmark_url]
        entry
      end
    rescue StandardError
      []
    end
  end
end
