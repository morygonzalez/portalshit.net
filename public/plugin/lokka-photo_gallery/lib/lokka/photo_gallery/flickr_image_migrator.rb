# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'set'
require 'tmpdir'
require_relative '../photo_gallery'

module Lokka
  module PhotoGallery
    # Matches Flickr CDN URLs in entry bodies with already-downloaded images,
    # uploads one copy per photo to the site's S3 bucket, and rewrites only the
    # CDN URLs. Links to Flickr photo pages are deliberately left untouched.
    class FlickrImageMigrator
      URL_REGEXP = %r{
        https?://
        (?:(?:[a-z0-9-]+\.)*staticflickr\.com|(?:[a-z0-9-]+\.)*static\.flickr\.com)
        /[^\s"'<>)]+
      }ix
      IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .webp .tif .tiff].freeze

      class UnresolvedImagesError < StandardError; end

      def initialize(entries:, image_directory:, explicit_mapping: {}, removal_photo_ids: [])
        @entries = entries
        @image_directory = File.expand_path(image_directory)
        @explicit_mapping = explicit_mapping.transform_keys(&:to_s)
        @removal_photo_ids = removal_photo_ids.map(&:to_s).to_set
      end

      def build_plan
        references = collect_references
        candidates = local_candidates(references.keys)

        photos = references.sort.map do |photo_id, reference|
          paths = mapped_paths(photo_id, candidates)
          build_photo_plan(photo_id, reference, paths)
        end

        {
          image_directory: @image_directory,
          entry_count: references.values.flat_map { |item| item[:entry_ids].to_a }.uniq.count,
          source_url_count: references.values.sum { |item| item[:source_urls].count },
          photo_count: photos.count,
          resolved_count: photos.count { |photo| photo[:status] == 'resolved' },
          removal_count: photos.count { |photo| photo[:status] == 'remove' },
          missing_count: photos.count { |photo| photo[:status] == 'missing' },
          ambiguous_count: photos.count { |photo| photo[:status] == 'ambiguous' },
          photos: photos
        }
      end

      def apply!(plan, uploader:, strip_gps: true)
        unresolved = plan[:photos].reject { |photo| %w[resolved remove].include?(photo[:status]) }
        unless unresolved.empty?
          ids = unresolved.map { |photo| photo[:photo_id] }.join(', ')
          raise UnresolvedImagesError, "対応する画像を一意に決められない photo ID: #{ids}"
        end

        ensure_exiftool! if strip_gps

        resolved_photos = plan[:photos].select { |photo| photo[:status] == 'resolved' }
        removal_photos = plan[:photos].select { |photo| photo[:status] == 'remove' }

        resolved_photos.each do |photo|
          upload(photo, uploader, strip_gps: strip_gps)
        end

        replacements = resolved_photos.each_with_object({}) do |photo, result|
          photo[:source_urls].each { |source_url| result[source_url] = photo[:target_url] }
        end

        updated_entries = 0
        Entry.transaction do
          @entries.each do |entry|
            original_body = entry.raw_body.to_s
            body = original_body
            body = removal_photos.reduce(body) do |result, photo|
              remove_flickr_embed(result, photo[:source_urls])
            end
            rewritten = replacements.reduce(body) do |result, (source_url, target_url)|
              result.gsub(source_url, target_url)
            end
            next if rewritten == original_body

            # 本文の意味や公開日時は変わらない移行なので、更新通知や
            # updated_at の変更を発生させない。
            entry.update_columns(body: rewritten)
            updated_entries += 1
          end
        end

        {
          uploaded_photos: resolved_photos.count,
          removed_photos: removal_photos.count,
          updated_entries: updated_entries
        }
      end

      private

      def collect_references
        @entries.each_with_object({}) do |entry, references|
          entry.raw_body.to_s.scan(URL_REGEXP).uniq.each do |url|
            photo_id = photo_id_from_url(url)
            next unless photo_id

            reference = (references[photo_id] ||= { source_urls: Set.new, entry_ids: Set.new })
            reference[:source_urls] << url
            reference[:entry_ids] << entry.id
          end
        end
      end

      def photo_id_from_url(url)
        File.basename(url.split(/[?#]/, 2).first)[/\A(\d+)_/, 1]
      end

      def local_candidates(expected_photo_ids)
        expected = expected_photo_ids.to_set
        result = Hash.new { |hash, key| hash[key] = [] }

        Dir.glob(File.join(@image_directory, '**', '*'), File::FNM_DOTMATCH).sort.each do |path|
          next unless File.file?(path)
          next if path.split(File::SEPARATOR).include?('__MACOSX')
          next if File.basename(path).start_with?('._')
          next unless IMAGE_EXTENSIONS.include?(File.extname(path).downcase)

          File.basename(path).scan(/\d{5,}/).uniq.each do |number|
            result[number] << File.expand_path(path) if expected.include?(number)
          end
        end

        result
      end

      def mapped_paths(photo_id, candidates)
        explicit_path = @explicit_mapping[photo_id]
        return [File.expand_path(explicit_path, @image_directory)] if explicit_path

        candidates.fetch(photo_id, []).uniq
      end

      def build_photo_plan(photo_id, reference, paths)
        status = if @removal_photo_ids.include?(photo_id)
                   'remove'
                 elsif paths.empty?
                   'missing'
                 elsif paths.one? && File.file?(paths.first)
                   'resolved'
                 else
                   'ambiguous'
                 end

        path = paths.first if status == 'resolved'
        target_key = content_key(path) if path

        {
          photo_id: photo_id,
          status: status,
          local_path: path,
          candidates: paths,
          target_key: target_key,
          target_url: target_key && "#{RESOURCE_BASE_URL}/#{target_key}",
          source_urls: reference[:source_urls].to_a.sort,
          entry_ids: reference[:entry_ids].to_a.sort
        }
      end

      def content_key(path)
        "#{Digest::MD5.file(path).hexdigest}#{File.extname(path).downcase}"
      end

      def remove_flickr_embed(body, source_urls)
        result = source_urls.reduce(body) do |html, source_url|
          escaped_url = Regexp.escape(source_url)
          linked_image = %r{
            <a\b[^>]*>\s*
            <img\b[^>]*\bsrc=(?:"#{escaped_url}"|'#{escaped_url}')[^>]*>\s*
            </a>\s*
          }imx
          standalone_image = %r{
            <img\b[^>]*\bsrc=(?:"#{escaped_url}"|'#{escaped_url}')[^>]*>\s*
          }imx

          html.sub(linked_image, '').sub(standalone_image, '')
        end

        return result if result.match?(/data-flickr-embed/i)

        result.gsub(
          %r{<script\b[^>]*\bsrc=(?:"|')?//embedr\.flickr\.com/assets/client-code\.js(?:"|')?[^>]*>\s*</script>\s*}im,
          ''
        )
      end

      def upload(photo, uploader, strip_gps:)
        return uploader.upload(photo[:local_path], photo[:target_key]) unless strip_gps

        Dir.mktmpdir('flickr-image-migration') do |directory|
          prepared_path = File.join(directory, File.basename(photo[:local_path]))
          FileUtils.cp(photo[:local_path], prepared_path)
          success = system('exiftool', '-overwrite_original', '-gps:all=', prepared_path,
                           out: File::NULL, err: File::NULL)
          raise "GPS情報を除去できませんでした: #{photo[:local_path]}" unless success

          uploader.upload(prepared_path, photo[:target_key])
        end
      end

      def ensure_exiftool!
        return if system('exiftool', '-ver', out: File::NULL, err: File::NULL)

        raise 'GPS情報を除去するための exiftool が見つかりません。インストールするか --keep-gps を指定してください。'
      end
    end
  end
end
