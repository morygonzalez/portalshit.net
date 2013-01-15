module Lokka
  module Archives
    def self.registered(app)
      app.get '/archives' do
        @month_posts = posts_group_by_month
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end
    end
  end

  module Helpers
    def posts_group_by_month
      posts_all = Post.all
      months.each_with_object({}) do |month, posts|
        posts_select_by_month = posts_all.select {|post|
          post.created_at.strftime('%Y-%m') == "#{month.year}-#{month.month}"
        }
        posts[month] = posts_select_by_month
      end
    end
  end
end
