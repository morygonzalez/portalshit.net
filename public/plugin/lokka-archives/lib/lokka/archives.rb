module Lokka
  module Archives
    def self.registered(app)
      app.set :cache_enabled, true

      app.get '/archives' do
        posts = Post.all(:created_at => (1.year.ago..Time.now))
        @month_posts = posts_group_by_month(posts)
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.get '/archives/:year' do |year|
        posts = Post.all(
          :created_at => (
            Time.parse("#{year}-01-01T00:00:00")..Time.parse("#{year}-12-31T23:59:59")
          )
        )
        @month_posts = posts_group_by_month(posts)
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
          EOS
        end
      end
    end
  end

  module Helpers
    def posts_group_by_month(posts)
      result = months.each_with_object({}) do |month, result|
        result[month] = posts.select {|post|
          post.created_at.strftime('%Y-%m') == "#{month.year}-#{month.month}"
        }
      end
      result.delete_if {|key, value| value.blank? }
    end

    def year_list
      first_year = Post.all.first.created_at.year
      last_year  = Post.all.last.created_at.year
      years = first_year.downto(last_year)
      link_arr = years.inject([]) {|result, year|
        result << year
      }
    end
  end
end
