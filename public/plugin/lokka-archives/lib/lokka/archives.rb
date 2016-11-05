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
        month_posts = MonthPosts.generate(posts)

        content_type :json
        month_posts.to_json
      end

      app.get '/archives/?:year?.json' do |year|
        posts = Post.all(
          fields: [:id, :category_id, :slug, :title, :created_at],
          draft: false,
          created_at: (Time.new(year)..Time.new(year).end_of_year)
        )
        month_posts = MonthPosts.generate(posts)

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
    end
  end

  module Helpers
    def year_list
      first_year = Post.published.first.created_at.year
      last_year  = Post.published.last.created_at.year
      first_year.downto(last_year).to_a
    end
  end

  module AddDateTimeMethodsToEntry
    refine Entry do
      def year
        self.created_at.year.to_s.rjust(4,'0')
      end

      def monthnum
        self.created_at.month.to_s.rjust(2,'0')
      end

      def month
        self.created_at.month.to_s.rjust(2,'0')
      end

      def day
        self.created_at.day.to_s.rjust(2,'0')
      end

      def hour
        self.created_at.hour.to_s.rjust(2,'0')
      end

      def minute
        self.created_at.min.to_s.rjust(2,'0')
      end

      def second
        self.created_at.sec.to_s.rjust(2,'0')
      end

      def post_id
        self.id.to_s
      end

      def postname
        self.slug || self.id.to_s
      end

      def clever_link
        if permalink_format
          params = permalink_keys.each_with_object({}) {|key, hash| hash[key] = eval("self.#{key}") }
          helper.custom_permalink_path(params)
        else
          self.slug
        end
      end

      private

      def helper
        Lokka::Helpers
      end

      def permalink_format
        @permalink_format ||= helper.custom_permalink_format if helper.custom_permalink?
      end

      def permalink_keys
        @permalink_keys ||= permalink_format.map {|item| item.sub(/(?:%(.+?)%)?\/?/, '\1') }.delete_if(&:blank?).map(&:to_sym)
      end
    end
  end

  class MonthPosts
    using AddDateTimeMethodsToEntry

    class << self
      def categories
        @categories ||= Category.all(fields: [:id, :slug, :title]).group_by(&:id)
      end

      def generate(posts)
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
              title: post.title,
              link: post.clever_link,
              created_at: post.created_at
            }
          end
          object
        }
      end
    end
  end
end
