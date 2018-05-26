module Lokka
  module OGP
    module AddImagesToEntry
      refine Entry do
        def images
          self.body.scan(/https?:\/\/[\w\/:%#\$&\?\(\)~\.=\+\-]+?\.(?:png|jpe?g|gif)/)
        end
      end
    end

    class BaseHash
      include Padrino::Helpers::FormatHelpers

      def initialize(entry: nil, site: nil, request: nil, theme: nil)
        @entry   = entry
        @site    = site
        @request = request
        @theme   = theme
      end

      def site_host
        "#{@request.scheme}://#{@request.host}"
      end

      def default_image
        "#{site_host}#{@theme.path}/screenshot.png"
      end

      def entry_link
        "#{site_host}#{@entry.link}"
      end

      def extract_description
        content = strip_tags(@entry.body).strip.gsub(/[\t]+/, ' ').gsub(/[\r\n]/, '')
        content = @site.meta_description if content.blank?
        truncate(content, length: 200)
      end
    end

    class OGPHash < BaseHash
      using AddImagesToEntry

      def website
        {
          "og:type"        => "website",
          "og:url"         => site_host,
          "og:title"       => @site.title,
          "og:description" => @site.meta_description,
          "og:image"       => default_image
        }
      end

      def article
        {
          "og:type"                   => "article",
          "og:url"                    => entry_link,
          "og:title"                  => @entry.title,
          "og:description"            => extract_description,
          "og:image"                  => @entry.images.first || default_image,
          "og:article:published_time" => @entry.created_at,
          "og:article:author"         => @entry.user.name
        }
      end

      def generate
        if @entry.present?
          article
        else
          website
        end
      end
    end

    class TwitterCardHash < BaseHash
      using AddImagesToEntry

      def summary
        {
          "twitter:card"        => "summary",
          "twitter:site"        => @site.title,
          "twitter:creator"     => "@#{User.first&.name}",
          "twitter:title"       => @site.title,
          "twitter:description" => @site.meta_description,
          "twitter:image"       => default_image,
          "twitter:url"         => site_host
        }
      end

      def entry_default
        {
          "twitter:card"        => detect_card_type,
          "twitter:site"        => @site.title,
          "twitter:creator"     => "@#{@entry.user.name}",
          "twitter:title"       => "#{@entry.title}",
          "twitter:description" => extract_description,
          "twitter:image"       => default_image,
          "twitter:url"         => entry_link
        }
      end

      def entry_without_image
        entry_default
      end

      def entry_with_image
        entry_default.merge("twitter:image" => @entry.images.first)
      end

      def entry_with_images
        images = @entry.images.each_with_index.each_with_object({}) {|(url, i), _images|
          break _images if i > 3
          _images["twitter:image#{i}"] = url
        }
        default = entry_default
        default.delete("twitter:image")
        default.merge(images)
      end

      def generate
        case
        when @entry.nil?
          summary
        when @entry
          case
          when @entry.images.nil?
            entry_without_image
          when @entry.images.length == 1
            entry_with_image
          when @entry.images.length > 1
            entry_with_images
          else
            entry_default
          end
        else
          entry_default
        end
      end

      def detect_card_type
        image = @entry.images.first
        width, height = FastImage.size(image)
        if width > 639 || height > 639
          # return 'gallery' if @entry.images.length > 1
          'summary_large_image'
        else
          'summary'
        end
      rescue
        'summary'
      end
    end

    module RefineHash
      refine Hash do
        def to_meta_tags
          self.each_with_object(SafeBuffer.new) do |(name, content), final|
            final << "<meta property=\"#{name}\" content=\"#{content}\" />\n".html_safe
          end
        end
      end
    end
  end
end
