require 'dm-serializer/to_json'

module Lokka
  module Archives
    def self.registered(app)
      app.get '/archives.json' do
        posts = Post.all(
          fields: [:id, :category_id, :slug, :title, :created_at],
          draft: false,
          created_at: (1.year.ago..Time.now)
        )
        month_posts = EntryHashGenerator.generate(posts)

        content_type :json
        month_posts.to_json
      end

      app.get '/archives/?:year?.json' do |year|
        posts = Post.all(
          fields: [:id, :category_id, :slug, :title, :created_at],
          draft: false,
          created_at: (Time.new(year)..Time.new(year).end_of_year)
        )
        month_posts = EntryHashGenerator.generate(posts)

        content_type :json
        month_posts.to_json
      end

      app.get '/archives' do
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.get '/archives/:year' do |year|
        @bread_crumbs = [{:name => t('home'), :link => '/'}]
        @bread_crumbs << {:name => t('archives.title'), :link => '/archives'}
        @bread_crumbs << {:name => year, :link => "/archives/#{year}"}
        haml :"plugin/lokka-archives/views/index", :layout => :"theme/#{@theme.name}/layout"
      end

      app.before do
        assets_path = "/plugin/lokka-archives/assets"
        content_for :header do
          <<-EOS.strip_heredoc
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

  class EntryHashGenerator
    class << self
      def generate(posts)
        categories = Category.all(fields: [:id, :slug, :title]).group_by(&:id)
        month_posts = posts.group_by {|post| post.created_at.strftime('%Y-%1m') }
        month_posts.each_with_object({}) {|(month, _posts), object|
          object[month] ||= []
          _posts.each do |post|
            category = categories[post.category_id]&.first || {}
            object[month] << {
              id: post.id,
              category: {
                id: category[:id],
                title: category[:title],
                slug: category[:slug]
              },
              slug: post.slug,
              title: post.title,
              created_at: post.created_at
            }
          end
          object
        }
      end
    end
  end
end
