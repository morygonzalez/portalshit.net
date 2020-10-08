module Lokka
  module Archives
    module AddDateTimeMethodsToPost
      refine Post do
        def year
          created_at.year.to_s.rjust(4, '0')
        end

        def monthnum
          created_at.month.to_s.rjust(2, '0')
        end

        def month
          created_at.month.to_s.rjust(2, '0')
        end

        def day
          created_at.day.to_s.rjust(2, '0')
        end

        def hour
          created_at.hour.to_s.rjust(2, '0')
        end

        def minute
          created_at.min.to_s.rjust(2, '0')
        end

        def second
          created_at.sec.to_s.rjust(2, '0')
        end

        def post_id
          id.to_s
        end

        def postname
          slug || id.to_s
        end

        def clever_link
          if permalink_format
            params = permalink_keys.each_with_object({}) {|key, hash| hash[key] = send(key) }
            permalink_helper.custom_permalink_path(params)
          else
            slug
          end
        end

        private

        def permalink_helper
          Lokka::PermalinkHelper
        end

        def permalink_format
          @permalink_format ||= permalink_helper.custom_permalink_format if permalink_helper.custom_permalink?
        end

        def permalink_keys
          @permalink_keys ||=
            permalink_format.map {|item| item.sub(%r{(?:%(.+?)%)?/?}, '\1') }.
            delete_if(&:blank?).map(&:to_sym)
        end
      end
    end

    class Aggregator
      using AddDateTimeMethodsToPost

      class << self
        def categories
          @categories ||= Category.find(
            Category.joins(:entries).where(entries: Post.published).
            group(:id).order(count_entries_id: :desc).count(:'entries.id').
            keys
          )
        end

        def generate(posts)
          posts.includes(:tags).group_by {|post| post.created_at.beginning_of_month.to_formatted_s(:db) }.
            each_with_object({}) do |(month, month_posts), object|
              object[month] ||= []
              month_posts.each do |post|
                category = categories.find {|c| c.id == post.category_id }
                object[month] << {
                  id: post.id,
                  category: { id: category[:id], title: category[:title], slug: category[:slug] },
                  tags: post.tags,
                  title: post.title,
                  link: post.clever_link,
                  created_at: post.created_at
                }
              end
              object
            end
        end
      end
    end
  end
end
