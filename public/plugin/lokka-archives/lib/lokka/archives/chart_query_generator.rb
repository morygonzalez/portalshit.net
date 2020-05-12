# frozen_string_literal: true

module Lokka
  module Archives
    class ChartQueryGenerator
      class << self
        def run
          self.new.chart
        end
      end

      attr_reader :database

      def initialize
        @database = case Lokka.database_config.to_s
                    when /mysql/
                      :mysql
                    when /postgres/
                      :postgres
                    when /sqlite/
                      :sqlite
                    else
                      nil
                    end
      end

      def chart
        sql_chart || ruby_chart
      end

      def sql_chart
        return nil if query.nil?

        result = ActiveRecord::Base.connection.select_all(query)
        grouped = result.map(&:to_h).group_by {|record| record['year'] }
        grouped.each_with_object([]) {|(year, record), outer|
          outer << record.each_with_object({ year: year }) {|item, inner|
            _, category, count = item.values
            inner[category] = count
          }
        }
      end

      def query
        @query ||= database ? send(:"#{database}_query") : nil
      end

      def ruby_chart
        posts = Post.unscoped.published.select(%i[id category_id created_at]).includes(:category)
        grouped = posts.group_by {|post| [post.created_at.year, post.category&.title] }
        group_by_year = grouped.group_by {|(year, category), entries| year }
        group_by_year.each_with_object([]) {|(year, records), outer|
          outer << records.each_with_object({ year: year }) {|((_, category), entries), inner|
            inner[category] = entries.length
          }
        }.reverse
      end

      private

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
    end
  end
end
