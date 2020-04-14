# frozen_string_literal: true

require 'dm-serializer/to_json'

module Lokka
  module Archives
    def self.registered(app)
      app.get '/archives.json' do
        posts = Post.all(
          fields: %i[id category_id slug title created_at],
          draft: false
        )
        month_posts = MonthPosts.generate(posts)

        cache_control :public, :must_revalidate, max_age: 5.minutes
        content_type :json
        month_posts.to_json
      end

      app.get '/archives/years.json' do
        content_type :json
        year_list.to_json
      end

      app.get '/archives/categories.json' do
        content_type :json
        categories.to_json
      end

      app.get '/archives/chart.json' do
        result = Post.repository.adapter.select(
          <<~SQL
            SELECT
              YEAR(entries.created_at) AS year,
              categories.title as category,
              COUNT(1) AS count
            FROM entries
            INNER JOIN categories ON categories.id = entries.category_id
            WHERE entries.draft = FALSE AND entries.type = 'Post'
            GROUP BY year, category
            ORDER BY year
          SQL
        )

        content_type :json
        grouped = result.map(&:to_h).group_by {|record| record[:year] }
        grouped.each_with_object([]) {|(year, record), object_1|
          object_1 << record.each_with_object({ year: year }) {|item, object_2|
            _, category, count = item.values
            object_2[category] = count
          }
        }.to_json
      end

      app.get '/archives/?:year?.json' do |year|
        posts = Post.all(
          fields: %i[id category_id slug title created_at],
          draft: false,
          created_at: (Time.new(year)..Time.new(year).end_of_year)
        )
        month_posts = MonthPosts.generate(posts)

        content_type :json
        month_posts.to_json
      end

      app.get '/archives' do
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('archives.title'), link: '/archives' }
        haml :"plugin/lokka-archives/views/index", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/archives/:year' do |year|
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('archives.title'), link: '/archives' }
        @bread_crumbs << { name: year, link: "/archives/#{year}" }
        haml :"plugin/lokka-archives/views/index", layout: :"theme/#{@theme.name}/layout"
      end
    end
  end

  module Helpers
    def year_list
      first_year, last_year = Post.published.aggregate(:created_at.min, :created_at.max).map(&:year)
      last_year.downto(first_year).to_a
      # Post.published.group_by {|entry| entry.created_at.year }.transform_values(&:length)
    end

    def categories
      MonthPosts.categories.values.flatten.map(&:title)
    end
  end

  module AddDateTimeMethodsToEntry
    refine Entry do
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
          helper.custom_permalink_path(params)
        else
          slug
        end
      end

      private

      def helper
        Lokka::Helpers
      end

      def permalink_format
        @permalink_format ||= helper.custom_permalink_format if helper.custom_permalink?
      end

      def permalink_keys
        @permalink_keys ||=
          permalink_format.map {|item| item.sub(%r{(?:%(.+?)%)?/?}, '\1') }.
            delete_if(&:blank?).map(&:to_sym)
      end
    end
  end

  class MonthPosts
    using AddDateTimeMethodsToEntry

    class << self
      def categories
        @categories ||= Category.all(fields: %i[id slug title]).sort_by {|c| -c.entries.count }.group_by(&:id)
      end

      def generate(posts)
        posts.group_by {|post| post.created_at.beginning_of_month }.
          each_with_object({}) do |(month, month_posts), object|
            object[month] ||= []
            month_posts.each do |post|
              category = categories[post.category_id]&.first || {}
              object[month] << {
                id: post.id,
                category: { id: category[:id], title: category[:title], slug: category[:slug] },
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
