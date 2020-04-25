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
        content_type :json
        chart.to_json
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
    end

    def categories
      MonthPosts.categories.values.flatten.map(&:title)
    end

    def chart
      sql_chart || ruby_chart
    end

    private

    def sql_chart
      query = case Lokka.database_config.to_s
              when /mysql/
                mysql_query
              when /postgres/
                postgres_query
              when /sqlite/
                sqlite_query
              else
                nil
              end
      return nil if query.nil?

      result = Post.repository.adapter.select(query)
      grouped = result.map(&:to_h).group_by {|record| record[:year] }
      grouped.each_with_object([]) {|(year, record), outer|
        outer << record.each_with_object({ year: year }) {|item, inner|
          _, category, count = item.values
          inner[category] = count
        }
      }
    end

    def postgres_query
      <<~SQL
        SELECT
          TO_CHAR(entries.created_at, 'YYYY') AS year,
          categories.title as category,
          COUNT(1) AS count
        FROM entries
        INNER JOIN categories ON categories.id = entries.category_id
        WHERE entries.draft = FALSE AND entries.type = 'Post'
        GROUP BY year, category
        ORDER BY year
      SQL
    end

    def mysql_query
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
    end

    def sqlite_query
      <<~SQL
        SELECT
          strftime('%Y', entries.created_at) AS year,
          categories.title as category,
          COUNT(1) AS count
        FROM entries
        INNER JOIN categories ON categories.id = entries.category_id
        WHERE entries.draft = 'f' AND entries.type = 'Post'
        GROUP BY year, category
        ORDER BY year
      SQL
    end

    def ruby_chart
      posts = Post.all(fields: %i[id category_id created_at], draft: false)
      grouped = posts.group_by {|post| [post.created_at.year, post.category&.title] }
      group_by_year = grouped.group_by {|(year, category), entries| year }
      group_by_year.each_with_object([]) {|(year, records), outer|
        outer << records.each_with_object({ year: year }) {|((_, category), entries), inner|
          inner[category] = entries.length
        }
      }.reverse
    end
  end

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
    using AddDateTimeMethodsToPost

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
