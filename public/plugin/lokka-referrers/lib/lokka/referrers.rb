module Lokka
  module AddReferrersToEntry
    class Entry
      def referrers
        Entry.all(:body.like => "%#{link}%")
      end
    end
  end

  module Helpers
    using AddReferrersToEntry

    def referrers
      @entry.referrers
    end
  end

  module Referrers
    def self.registered(app); end
  end
end
