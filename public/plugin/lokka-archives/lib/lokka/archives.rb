module Lokka
  module Archives
    def self.registered(app)
      app.get %r{/archives/?(\d{4})?} do |year|
        @month_posts = posts_group_by_month(year)
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.before do
        assets_path = "/plugin/lokka-archives/assets"
        content_for :header do
          text = <<-EOS
          <link href="#{assets_path}/style.css" rel="stylesheet" type="text/css" />
          EOS
        end
      end
    end
  end

  module Helpers
    def posts_group_by_month(target_year = Date.today.year)
      first_post_year = Post.all.first.created_at.to_date.year
      last_post_year  = Post.all.last.created_at.to_date.year
      posts_all = Post.all(
        :created_at => (Time.parse("#{target_year}-01-01")..Time.parse("#{target_year}-12-31"))
      )
      months.each_with_object({}) do |month, posts|
        if month.year == target_year
          posts_select_by_month = posts_all.select {|post|
            post.created_at.strftime('%Y-%m') == "#{month.year}-#{month.month}"
          }
          posts[month] = posts_select_by_month
        end
      end
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
