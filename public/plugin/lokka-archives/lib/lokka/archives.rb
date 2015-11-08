require 'dm-serializer/to_json'

module Lokka
  module Archives
    def self.registered(app)
      app.set :cache_enabled, true

      app.get '/archives' do
        cache_path = app.public_dir + '/archives.html'
        if test(?f, cache_path) && Time.now - test(?M, cache_path) < 15.minutes
          return File.read(cache_path)
        end
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.get '/api/archives' do
        @month_posts = Post.all(draft: false, created_at: (1.year.ago..Time.now)).
          group_by {|post| post.created_at.strftime('%Y-%1m') }

        content_type :json
        fields_to_exclude = %i[body markup type slug user_id category_id updated_at draft frozen_tag_list]
        methods_to_include = %i[link category]
        @month_posts.to_json(
          exclude: fields_to_exclude,
          methods: methods_to_include
        )
      end

      app.get '/archives/:year' do |year|
        cache_path = app.public_dir + "/archives/#{year}.html"
        if test(?f, cache_path) && Time.now - test(?M, cache_path) < 15.minutes
          return File.read(cache_path)
        end
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        @bread_crumbs << {:name => year, :link => "/archives/#{year}"}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.get '/api/archives/:year' do |year|
        @month_posts = Post.all(
          :draft => false,
          :created_at => (
            Time.new(year)..Time.new(year).end_of_year
          )
        ).group_by {|post| post.created_at.strftime('%Y-%1m') }

        content_type :json
        fields_to_exclude = %i[body markup type slug user_id category_id updated_at draft frozen_tag_list]
        methods_to_include = %i[link category]
        @month_posts.to_json(
          exclude: fields_to_exclude,
          methods: methods_to_include
        )
      end

      app.before do
        assets_path = "/plugin/lokka-archives/assets"
        content_for :header do
          text = <<-EOS.strip_heredoc
            <link href="#{assets_path}/style.css" rel="stylesheet" type="text/css" />
            <script src="https://cdnjs.cloudflare.com/ajax/libs/react/0.14.2/react.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/react/0.14.2/react-dom.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/babel-core/5.8.23/browser.js"></script>
            <script type="text/babel" src="#{assets_path}/script.js"></script>
          EOS
        end
      end
    end
  end

  module Helpers
    def year_list
      first_year = Post.published.first.created_at.year
      last_year  = Post.published.last.created_at.year
      first_year.downto(last_year).to_a
    end
  end
end
