# frozen_string_literal: true

module Lokka
  module Importer
    class WordPress
      DEFAULT_PASSWORD = 'test'

      def initialize(file)
        @file = file
      end

      def import
        doc = Nokogiri::XML(@file.read.gsub(//, ''))
        doc.xpath('/rss/channel',
                  'content' => 'http://purl.org/rss/1.0/modules/content/',
                  'wp' => 'http://wordpress.org/export/1.1/',
                  'dc' => 'http://purl.org/dc/elements/1.1/').each do |channel|
          Site.first.update(
            title: channel.xpath('title').text,
            description: channel.xpath('description').text
          )

          channel.xpath('wp:author').each do |author|
            name = author.xpath('wp:author_login').text
            user = User.first(name: name)

            user ||= User.new(
              name: name,
              password: DEFAULT_PASSWORD,
              password_confirmation: DEFAULT_PASSWORD
            )

            user.email = author.xpath('wp:author_email').text
            user.save
          end

          channel.xpath('wp:category').each do |category|
            Category.first_or_create(
              slug: category.xpath('wp:cat_name').text,
              title: category.xpath('wp:category_nicename').text
            )
          end

          channel.xpath('item').each do |item|
            model =
              case item.xpath('wp:post_type').text
              when 'post'
                Post
              when 'page'
                Page
              else
                next
              end

            # Skip if a post is in draft mode and the post date is 0000-00-00 00:00:00
            next if item.xpath('wp:post_date_gmt').text == '0000-00-00 00:00:00'

            attrs = {
              id: item.xpath('wp:post_id').text.to_i,
              title: item.xpath('title').text,
              body: item.xpath('content:encoded').text,
              draft: item.xpath('wp:status').text != 'publish',
              slug: item.xpath('wp:post_name').text,
              created_at: Time.parse(item.xpath('wp:post_date_gmt').text),
              updated_at: Time.parse(item.xpath('wp:post_date_gmt').text)
            }

            entry = model.first_or_create(id: attrs[:id])
            entry.attributes = attrs

            # author
            item.xpath('dc:creator').each do |creator|
              entry.user = User.first(name: creator.text)
              break
            end

            # tag
            item.xpath('category[@domain="post_tag"]').each do |tag|
              entry.tag_list << tag.text
            end

            # category
            item.xpath('category[@domain="category"]').each do |category|
              entry.category = Category.first(title: category.text)
            end

            entry.save

            # comment
            entry.comments.destroy
            item.xpath('wp:comment').each do |comment|
              comment = entry.comments.new(
                name: comment.xpath('wp:comment_author').text,
                email: comment.xpath('wp:comment_email').text,
                body: comment.xpath('wp:comment_content').text,
                created_at: comment.xpath('wp:comment_date').text,
                status: comment.xpath('wp:comment_approvied').text == '1' ? 1 : 0
              )
              comment.save
            end
          end
        end
      end
    end
  end
end
