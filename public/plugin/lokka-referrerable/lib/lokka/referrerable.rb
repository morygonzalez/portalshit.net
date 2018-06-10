# frozen_string_literal: true

module Lokka
  module Referrerable
    def self.registered(app); end
  end

  module Helpers
    def referrers
      Entry.all(:body.like => "%#{@entry.link}%")
    end
  end
end
