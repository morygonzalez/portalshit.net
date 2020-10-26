# frozen_string_literal: true

module Lokka
  module Referrerable
    def self.registered(app); end
  end

  module Helpers
    def referrers
      Entry.includes(:category).published.where('body like ?', "%#{@entry.link}%")
    end
  end
end
