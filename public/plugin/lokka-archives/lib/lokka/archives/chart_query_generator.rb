# frozen_string_literal: true

module Lokka
  module Archives
    class ChartQueryGenerator
      class << self
        def run(year)
          self.new(year).chart
        end
      end

      attr_reader :database

      def initialize(year)
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
        @year = year
      end

      def chart
        sql_chart || ruby_chart
      end

      def sql_chart
        return nil if query.nil?

        result = ActiveRecord::Base.connection.select_all(query)
        grouped = result.map(&:to_h).group_by {|record| record['duration'] }
        grouped.each_with_object([]) {|(duration, record), outer|
          outer << record.each_with_object({ duration: duration }) {|item, inner|
            _, category, count = item.values
            inner[category] = count
          }
        }
      end

      def identifier
        @identifier ||= @year.present? ? :week : :quarter
      end

      def query
        @query ||= database ? send(:"#{database}_query") : nil
      end

      def ruby_chart
        duration = identifier
        posts = Post.unscoped.published.select(%i[id category_id created_at]).includes(:category)
        if year
          posts = posts.where(created_at: Time.new(year)...Time.new(year + 1))
        end
        grouped = posts.group_by {|post| [post.created_at.send(duration), post.category&.title] }
        group_by_duration = grouped.group_by {|(duration, category), entries| duration }
        group_by_duration.each_with_object([]) {|(duration, records), outer|
          outer << records.each_with_object({ duration: duration }) {|((_, category), entries), inner|
            inner[category] = entries.length
          }
        }.reverse
      end

      private

      def postgres_query
        case identifier
        when :week
          postgres_weekly_query
        when :quarter
          postgres_quarterly_query
        else
          raise 'NoDurationSpecified'
        end
      end

      def postgres_quarterly_query
        <<~SQL
          SELECT
            TO_CHAR(entries.created_at, 'YYYY') || '-Q' || EXTRACT(QUARTER FROM entries.created_at) AS duration,
            categories.title AS category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = FALSE
            AND entries.type = 'Post'
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def postgres_weekly_query
        <<~SQL
          SELECT
            TO_CHAR(entries.created_at, 'IYYY-"W"IW') AS duration,
            categories.title AS category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = FALSE
            AND entries.type = 'Post'
            AND entries.created_at >= '#{@year}-01-01'
            AND entries.created_at < '#{@year.to_i + 1}-01-01'
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def mysql_query
        case identifier
        when :week
          mysql_weekly_query
        when :quarter
          mysql_quarterly_query
        else
          raise 'NoDurationSpecified'
        end
      end

      def mysql_quarterly_query
        <<~SQL
          SELECT
            CONCAT(YEAR(entries.created_at), '-Q', QUARTER(entries.created_at)) AS duration,
            categories.title as category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = FALSE AND entries.type = 'Post'
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def mysql_weekly_query
        <<~SQL
          SELECT
            DATE_FORMAT(entries.created_at, '%x-W%v') AS duration,
            categories.title as category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = FALSE
            AND entries.type = 'Post'
            AND entries.created_at >= '#{@year}-01-01'
            AND entries.created_at < '#{@year.to_i + 1}-01-01'
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def sqlite_query
        duration = identifier == :week ? '%Y-W%W' : '%Y-Q'
        year_filter = @year.present? ? %Q(AND entries.created_at BETWEEN '#{@year}-01-01' AND '#{@year}-12-31') : nil
        duration_sql = if identifier == :quarter
                         %Q(strftime('%Y', entries.created_at) || '-Q' || ((CAST(strftime('%m', entries.created_at) AS INTEGER) - 1) / 3 + 1))
                       else
                         %Q(strftime('#{duration}', entries.created_at))
                       end
        <<~SQL
          SELECT
            #{duration_sql} AS duration,
            categories.title as category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = 'f' AND entries.type = 'Post' #{year_filter}
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end
    end
  end
end
