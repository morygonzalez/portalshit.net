module Lokka
  module PopularEntries
    def self.registerd(app); end
  end
end

class Entry
  class << self
    def popular(count = 5)
      access_ranking = File.open(File.join(Lokka.root, 'public', 'access-ranking.txt'))
      slugs = {}
      access_ranking.each.with_index(1) do |line, index|
        access_count, path = *line.split(" ")
        slug = path.split("/")[-1]
        slugs[access_count] = slug
        break if index == count
      end
      all(slug: slugs.values, limit: count).sort_by {|entry| slugs.values.index(entry.slug) }
    end
  end
end
