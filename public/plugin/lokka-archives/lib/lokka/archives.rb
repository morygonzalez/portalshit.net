module Lokka
  module Archives
    def self.registered(app)
      app.get '/archives' do
        @posts = Post.all
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end
    end
  end
end
