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
        access_limit, path = *line.split(" ")
        slug = path.split("/")[-1]
        slugs[access_limit] = slug
        break if index == limit
      end
      all(slug: slugs.values, limit: limit).sort_by {|entry| slugs.values.index(entry.slug) }
    rescue
      []
    end

    def hotentry(limit = 5)
      require 'open-uri'
      require 'nokogiri'

      max = limit - 1
      url = 'http://b.hatena.ne.jp/entrylist?sort=count&url=portalshit.net'
      ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36'
      content = open(url, 'User-Agent' => ua).read
      doc = Nokogiri::HTML(content)
      slugs = doc.xpath('//li[contains(@class, "entry-unit")]')[0..max].inject({}) {|result, item|
        attributes = item.xpath('div[2]/h3/a')
        meta = item.xpath('div[2]/ul/li/span/a')[0]
        entry_url = '/entry/' + attributes.attr('href').value.gsub(%r{https?://}, '')
        slug = attributes.attr('href').value.gsub(%r{https?://(www\.)?portalshit\.net/(\d{4}/\d{2}/\d{2}/|article\.php\?id=)}, '')
        bookmark_count = item.attr('data-bookmark-count')
        bookmark_url = "http://b.hatena.ne.jp#{meta&.attr('href') || entry_url}"
        result[slug] = { bookmark_count: bookmark_count, bookmark_url: bookmark_url }
        result
      }
      entries = all(slug: slugs.keys, limit: limit).sort_by {|entry| slugs.keys.index(entry.slug) }
      entries.map {|entry|
        entry.bookmark_count = slugs[entry.slug][:bookmark_count]
        entry.bookmark_url = slugs[entry.slug][:bookmark_url]
        entry
      }
    # rescue
    #   []
    end
  end
end
