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
                      _result = fetch&.to_h.to_json
                      if _result =~ /error/i
                        logger.info(%(Failed fetching #{@item_id} due to #{_result}))
                        _result = nil
                      else
                        logger.info(%(Finished fetching #{@item_id}))
                      end
                      _result
                    end
      end

      class RetryQuotaOver < StandardError; end
    end
  end
end
