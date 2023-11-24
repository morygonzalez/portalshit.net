# frozen_string_literal: true

module Lokka
  module OGP
    module AddImagesToEntry
      refine Entry do
        def images
          doc = Nokogiri::HTML.fragment(body)
          doc.css('img:root, figure:root > img, p:root > video').map {|item|
            case item.name
            when "img"
              item.attributes["src"].value
            when "video"
              item.attributes["poster"].value
            end
          }
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
        if [443, 80].include?(@request.port)
          "#{@request.scheme}://#{@request.host}"
        else
          "#{@request.scheme}://#{@request.host}:#{@request.port}"
        end
      end

      def default_image
        @default_image ||= File.exist?("#{Lokka.root}/public/#{@theme.path}/ogp_image.png") ?
          "#{site_host}#{@theme.path}/ogp_image.png" : "#{site_host}#{@theme.path}/screenshot.png"
      end

      def og_image_path
        @og_image_path ||= begin
                             cache_dir = FileUtils.mkdir_p("#{Lokka.root}/public/og-image")
                             File.join(cache_dir, og_cache_name)
                           end
      end

      def og_cache_name
        @og_cache_name ||= "#{@entry.slug}-og-image.jpeg"
      end

      def og_image
        @og_image ||= begin
                        if @entry.present?
                          if @entry.images.present?
                            @entry.cover_image
                          else
                            if !File.exist?(og_image_path) || test('M', File.open(og_image_path)) < 1.month.ago
                              image_path = "#{Lokka.root}/public/plugin/lokka-ogp/assets/portalshit-og-base.jpg"
                              image = Lokka::OGP::Creator.build(text: @entry&.title, image: image_path)
                              image.format 'jpeg'
                              image.write(og_image_path)
                              FileUtils.chmod(0644, og_image_path)
                            end
                            "#{site_host}/og-image/#{og_cache_name}"
                          end
                        else
                          default_image
                        end
                      end
      end

      def entry_link
        "#{site_host}#{@entry.link}"
      end

      def extract_description
        content = strip_tags(@entry.long_description).strip.gsub(/[\t]+/, ' ').gsub(/[\r\n]/, '')
        content = @site.meta_description if content.blank?
        truncate(content, length: 100)
      end
    end

    class OGPHash < BaseHash
      using AddImagesToEntry

      def website
        {
          'og:type'        => 'website',
          'og:url'         => site_host,
          'og:title'       => @site.title,
          'og:description' => @site.meta_description,
          'og:image'       => default_image
        }
      end

      def article
        {
          'og:type'                   => 'article',
          'og:url'                    => entry_link,
          'og:title'                  => @entry.title,
          'og:description'            => extract_description,
          'og:image'                  => og_image,
          'og:article:published_time' => @entry.created_at,
          'og:article:author'         => @entry.user.name
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
          'twitter:card'        => 'summary',
          'twitter:site'        => @site.title,
          'twitter:creator'     => "@#{User.first&.name}",
          'twitter:title'       => @site.title,
          'twitter:description' => @site.meta_description,
          'twitter:image'       => og_image,
          'twitter:url'         => site_host
        }
      end

      def entry_default
        {
          'twitter:card'        => detect_card_type,
          'twitter:site'        => @site.title,
          'twitter:creator'     => "@#{@entry.user.name}",
          'twitter:title'       => @entry.title.to_s,
          'twitter:description' => extract_description,
          'twitter:image'       => og_image,
          'twitter:url'         => entry_link
        }
      end

      def entry_without_image
        entry_default
      end

      def entry_with_image
        entry_default.merge('twitter:image' => @entry.images.first)
      end

      def entry_with_images
        images = @entry.images.each_with_index.each_with_object({}) do |(url, i), entry_images|
          break entry_images if i > 3
          entry_images["twitter:image#{i}"] = url
        end
        default = entry_default
        default.delete('twitter:image')
        default.merge(images)
      end

      def generate
        return summary if @entry.nil?
        if @entry.images.nil?
          entry_without_image
        elsif @entry.images.length == 1
          entry_with_image
        elsif @entry.images.length > 1
          entry_with_images
        else
          entry_default
        end
      end

      def detect_card_type
        'summary_large_image'
      #   image = @entry.images.first
      #   width, height = FastImage.size(image)
      #   if width > 639 || height > 639
      #     # return 'gallery' if @entry.images.length > 1
      #     'summary_large_image'
      #   else
      #     'summary'
      #   end
      # rescue StandardError
      #   'summary'
      end
    end

    module RefineHash
      refine Hash do
        def to_meta_tags
          each_with_object(SafeBuffer.new) do |(name, content), final|
            final << "<meta property=\"#{name}\" content=\"#{content}\" />\n".html_safe
          end
        end
      end
    end
  end
end
