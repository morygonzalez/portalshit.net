# frozen_string_literal: true

require_relative 'archives/chart_query_generator'
require_relative 'archives/aggregator'

module Lokka
  module Archives
    def self.registered(app)
      app.get '/archives.json' do
        posts = Post.published.joins(:category)

        cache_control :public, :must_revalidate, max_age: 5.minutes
        content_type :json
        month_posts(posts).to_json
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
        posts = Post.published.joins(:category).where(
          created_at: (Time.new(year)..Time.new(year).end_of_year)
        )

        content_type :json
        month_posts(posts).to_json
      end

      app.get '/archives' do
        @title = %(#{I18n.t('archives.title')} - #{@site.title})
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('archives.title'), link: '/archives' }
        haml :"plugin/lokka-archives/views/index", layout: :"theme/#{@theme.name}/layout"
      end

      app.get '/archives/:year' do |year|
        @title = %(#{I18n.t('archives.title')} #{year} - #{@site.title})
        @bread_crumbs = [{ name: t('home'), link: '/' }]
        @bread_crumbs << { name: t('archives.title'), link: '/archives' }
        @bread_crumbs << { name: year, link: "/archives/#{year}" }
        haml :"plugin/lokka-archives/views/index", layout: :"theme/#{@theme.name}/layout"
      end
    end
  end

  module Helpers
    def year_list
      first_year = Post.published.minimum(:created_at).year
      last_year = Post.published.maximum(:created_at).year
      last_year.downto(first_year).to_a
    end

    def categories
      Archives::Aggregator.categories.map(&:title)
    end

    def month_posts(posts)
      Archives::Aggregator.generate(posts)
    end

    def chart
      Archives::ChartQueryGenerator.run
    end

    def archives_assets_path
      '/plugin/lokka-archives/assets'
    end

    def archives_manifest
      @archives_manifest ||= \
        begin
          file_path = File.join(Lokka.root, 'public', archives_assets_path, 'manifest.json')
          content = File.open(file_path).read
          JSON.parse(content)
        end
    end

    def archives_javascript_path(file_name)
      if Lokka.production?
        "#{archives_assets_path}/#{archives_manifest[file_name]}"
      else
        "/plugin/lokka-archives/build/#{file_name}"
      end
    end
  end
end
