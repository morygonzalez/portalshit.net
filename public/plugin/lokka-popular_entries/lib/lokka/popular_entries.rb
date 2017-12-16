module Lokka
  module PopularEntries
    def self.registerd(app); end
  end
end

class Entry
  class << self
    def popular(count = 5)
      access_ranking = File.open(File.join(Lokka.root, 'public', 'access-ranking.txt'))
      result = []
      access_ranking.each.with_index(1) do |line, index|
        _, path = *line.split(" ")
        path = path.split("/")[-1]
        result << Entry.get_by_fuzzy_slug(path)
        break if index == count
      end
      result
    end
  end
end
