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
        @identifier ||= @year.present? ? :month : :year
      end

      def query
        @query ||= database ? send(:"#{database}_query") : nil
      end

      def ruby_chart
        duration = identifier
        posts = Post.unscoped.published.select(%i[id category_id created_at]).includes(:category)
        if year
          posts.where(year: year)
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
        when :month
          postgres_monthly_query
        when :year
          postgres_yearly_query
        else
          raise 'NoDurationSpecified'
        end
      end

      def postgres_yearly_query
        <<~SQL
          SELECT
            TO_CHAR(entries.created_at, 'YYYY') AS duration,
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

      def postgres_monthly_query
        <<~SQL
          WITH date_series AS (
            SELECT
              generate_series(
                date_trunc('month', date('#{year}-01-01')),
                date('#{year}-12-31'),
                '1 month'
              ) AS month
          )
          SELECT
            date_series.yearmonth AS duration,
            categories.title AS category,
            COUNT(1) AS count
          FROM date_series
          LEFT JOIN entries
            ON to_char(entries.created_at, 'YYYY-MM') = date_series.yearmonth
            AND entries.draft = FALSE AND entries.type = 'Post'
          LEFT JOIN categories ON categories.id = entries.category_id
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def mysql_query
        case identifier
        when :month
          mysql_monthly_query
        when :year
          mysql_yearly_query
        else
          raise 'NoDurationSpecified'
        end
      end

      def mysql_yearly_query
        <<~SQL
          SELECT
            DATE_FORMAT(entries.created_at, '%Y') AS duration,
            categories.title as category,
            COUNT(1) AS count
          FROM entries
          INNER JOIN categories ON categories.id = entries.category_id
          WHERE entries.draft = FALSE AND entries.type = 'Post'
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def mysql_monthly_query
        <<~SQL
          SELECT
            date_series.yearmonth AS duration,
            categories.title as category,
            COUNT(1) AS count
          FROM (
            SELECT 0 row_no, 1 yearmonth
            WHERE (@num:=1-1)*0
            UNION ALL
            SELECT @num:=@num+1 row_no, concat('#{@year}-', LPAD(@num, 2, '0')) AS yearmonth
            FROM information_schema.COLUMNS
            LIMIT 12
          ) AS date_series
          LEFT JOIN entries
            ON DATE_FORMAT(entries.created_at, '%Y-%m') = date_series.yearmonth
            AND entries.draft = FALSE AND entries.type = 'Post'
          LEFT JOIN categories ON categories.id = entries.category_id
          GROUP BY duration, category
          ORDER BY duration
        SQL
      end

      def sqlite_query
        duration = identifier == :month ? '%m' : '%Y'
        year_filter = @year.present? ? %Q(AND entries.created_at BETWEEN '#{@year}-01-01' AND '#{@year}-12-31') : nil
        <<~SQL
          SELECT
            strftime('#{duration}', entries.created_at) AS duration,
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
