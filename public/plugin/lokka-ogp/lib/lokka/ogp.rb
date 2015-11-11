require 'fastimage'

module Lokka
  module OGP
    module AddImagesToEntry
      refine Entry do
        def images
          self.body.scan(/https?:\/\/[\w\/:%#\$&\?\(\)~\.=\+\-]+?\.(?:png|jpe?g|gif)/)
        end
      end
    end

    module Helpers
      using AddImagesToEntry

      def ogp
        website = -> {
          {
            "og:type"        => "website",
            "og:url"         => "#{@request.scheme}://#{@request.host}/",
            "og:title"       => @site.title,
            "og:description" => @site.meta_description,
            "og:image"       => "#{@request.scheme}://#{@request.host}#{@theme.path}/screenshot.png"
          }
        }
        article = -> {
          {
            "og:type"        => "article",
            "og:url"         => @entry.link,
            "og:title"       => @entry.title,
            "og:description" => extract_description_from(@entry),
            "og:image"       => @entry.images.first
          }
        }

        return website.call if defined?(@entry).nil?
        article.call
      end

      def twitter_card
        default = lambda {
          {
            "twitter:card"        => "summary",
            "twitter:site"        => @site.title,
            "twitter:creator"     => "@#{@entry.user.name}",
            "twitter:title"       => @entry.title,
            "twitter:description" => extract_description_from(@entry),
            "twitter:image"       => "#{@request.scheme}://#{@request.host}#{@theme.path}/screenshot.png",
            "twitter:url"         => "#{@request.scheme}://#{@request.host}/#{@entry.link}"
          }
        }

        case
        when defined?(@entry).nil?
          {
            "twitter:card"        => "summary",
            "twitter:site"        => @site.title,
            "twitter:creator"     => "@#{User.first.name}",
            "twitter:title"       => @site.title,
            "twitter:description" => @site.meta_description,
            "twitter:image"       => "#{@request.scheme}://#{@request.host}#{@theme.path}/screenshot.png",
            "twitter:url"         => "#{@request.scheme}://#{@request.host}/"
          }
        when @entry.images.present?
          case
          when @entry.images.length == 1
            {
              "twitter:card"        => detect_card_type_from(matched),
              "twitter:site"        => @site.title,
              "twitter:creator"     => "@#{@entry.user.name}",
              "twitter:title"       => "#{@entry.title}",
              "twitter:description" => extract_description_from(@entry),
              "twitter:image:src"   => @entry.iamges.first
            }
          when @entry.images.length > 1
            images = @entry.images.each_with_index.each_with_object({}) {|(url, i), _images|
              break _images if i > 3
              _images["twitter:image#{i}"] = url
            }
            {
              "twitter:card"        => detect_card_type_from(@entry.images),
              "twitter:site"        => @site.title,
              "twitter:creator"     => "@#{@entry.user.name}",
              "twitter:title"       => @entry.title,
              "twitter:description" => extract_description_from(@entry),
              "twitter:url"         => "#{@request.scheme}://#{@request.host}/#{@entry.link}",
            }.merge(images)
          else
            default.call
          end
        else
          default.call
        end
      end

      def extract_description_from(entry)
        content = strip_tags(entry.body).strip.gsub(/[\t]+/, ' ').gsub(/[\r\n]/, '')
        content = @site.meta_description if content.blank?
        truncate(content, length: 200)
      end

      def detect_card_type_from(photos)
        image = photos.first
        width, height = FastImage.size(image)
        if width > 639 || height > 639
          return 'gallery' if photos.length > 1
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
          self.each_with_object('') do |(name, content), final|
            final << "<meta name=\"#{name}\" content=\"#{content}\" />\n"
          end
        end
      end
    end

    using RefineHash

    def self.registered(app)
      app.helpers OGP::Helpers

      app.before do
        content_for :header do
          ogp.merge(twitter_card).to_meta_tags
        end
      end
    end
  end
end
