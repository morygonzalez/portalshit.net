# frozen_string_literal: true

module Lokka
  module AmazonAssociate
    class Fetcher
      include CacheControllable

      def initialize(item_id)
        @item_id = item_id
        @kind = :json
        @retry_amount = 0
        write_or_touch_cache unless cache_alive?
      end

      def logger
        @logger ||= begin
                      log_file = File.open(File.join(Lokka.root, 'log/amazon_paapi.log'), 'a')
                      Logger.new(log_file, 'weekly')
                    end
      end

      def fetch
        logger.info(%(Start fetching #{@item_id}))
        client = Vacuum.new(
          marketplace: 'JP',
          partner_tag: Option.associate_tag,
          access_key: Option.access_key_id,
          secret_key: Option.secret_key
        )
        resources = [
          'Images.Primary.Medium',
          'ItemInfo.ByLineInfo',
          'ItemInfo.Classifications',
          'ItemInfo.Title',
          'Offers.Listings.Price'
        ]
        begin
          lock
          response = client.get_items(item_ids: [@item_id], resources: resources)
        rescue => e
          logger.info(%(Failed fetching #{@item_id} due to #{e}))
        ensure
          unlock
        end
        response
      end

      private

      def lock
        while is_not_ready?
          logger.info(%(Blocked fetching #{@item_id}, retry_amount: #{@retry_amount}))
          @retry_amount += 1
          raise RetryQuotaOver, %(Retry quota exceeded, retry_amount: #{@retry_amount}) if retry_quota_over?
          sleep 1
        end
        FileUtils.touch(lockfile_path)
      end

      def unlock
        FileUtils.rm(lockfile_path)
      end

      def lockfile_path
        File.expand_path('tmp/amazon/lock')
      end

      def is_not_ready?
        FileTest.exist?(lockfile_path)
      end

      def retry_quota_over?
        @retry_amount > 2
      end

      def result
        @result ||= begin
                      response = ResponseParser.new(fetch)
                      if response.error?
                        logger.info(%(Failed fetching #{@item_id} due to #{response.error_messages}))
                        nil
                      else
                        logger.info(%(Finished fetching #{@item_id}))
                        response.json
                      end
                    end
      end

      class ResponseParser
        def initialize(result)
          @hash = result&.to_h
        end

        def error_messages
          errors.map {|e| e['Message'] }
        end

        def error?
          errors.present?
        end

        def json
          @hash.to_json
        end

        private

        def errors
          @errors ||= @hash['Errors']
        end
      end

      class RetryQuotaOver < StandardError; end
    end
  end
end
