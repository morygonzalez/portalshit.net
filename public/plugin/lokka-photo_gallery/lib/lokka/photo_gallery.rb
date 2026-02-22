module Lokka
  module PhotoGallery
    RESOURCE_BASE_URL   = 'https://resources.portalshit.net'.freeze
    IMAGEPROXY_BASE_URL = 'https://portalshit.net/imageproxy'.freeze
    IMAGE_EXTENSIONS    = %w[jpg jpeg png gif].freeze
    THUMBNAIL_SIZE      = '115'.freeze
    COVER_SIZE          = '1280x'.freeze

    def self.registered(app); end
  end
end
