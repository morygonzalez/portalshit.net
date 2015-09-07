module Lokka
  module Archives
    def self.registered(app)
      app.set :cache_enabled, true

      app.get '/archives' do
        cache_path = app.public_dir + '/archives.html'
        if test(?f, cache_path) && Time.now - test(?M, cache_path) < 15.minutes
          return File.read(cache_path)
        end
        @month_posts = Post.all(
          :draft => false, :created_at => (1.year.ago..Time.now)).
          group_by {|post| post.created_at.beginning_of_month }
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.get '/archives/:year' do |year|
        cache_path = app.public_dir + "/archives/#{year}.html"
        if test(?f, cache_path) && Time.now - test(?M, cache_path) < 15.minutes
          return File.read(cache_path)
        end
        @month_posts = Post.all(
          :draft => false,
          :created_at => (
            Time.parse("#{year}-01-01T00:00:00")..Time.parse("#{year}-12-31T23:59:59"))).
          group_by {|post| post.created_at.beginning_of_month }
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        @bread_crumbs << {:name => year, :link => "/archives/#{year}"}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.before do
        assets_path = "/plugin/lokka-archives/assets"
        content_for :header do
          text = <<-EOS.strip_heredoc
            <link href="#{assets_path}/style.css" rel="stylesheet" type="text/css" />
            <script src="#{assets_path}/script.js" type="text/javascript"></script>
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
