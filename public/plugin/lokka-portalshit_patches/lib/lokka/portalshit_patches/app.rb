require 'cgi'

module Lokka
  class App
    configure do
      bg_images = YAML.load_file(File.join(File.dirname(__FILE__), '../../../', 'config.yml'))['header_bg']
      set :header_bg_params, -> {
        dark_image = bg_images['dark'].sample
        light_image = bg_images['light'].sample
        {
          'data-bg-dark-image': "dark-#{dark_image['name']}",
          'data-bg-dark-description': dark_image['description'],
          'data-bg-dark-coord': dark_image['coord'],
          'data-bg-dark-apple-map-url': "https://maps.apple.com/?ll=#{dark_image['coord']}&q=#{CGI.escape(dark_image['description'])}",
          'data-bg-light-image': "light-#{light_image['name']}",
          'data-bg-light-description': light_image['description'],
          'data-bg-light-coord': light_image['coord'],
          'data-bg-light-apple-map-url': "https://maps.apple.com/?ll=#{light_image['coord']}&q=#{CGI.escape(light_image['description'])}"
        }
      }

      # インデックス本体は Search.index が持つ。ここで set :search_index に
      # proc を渡すと、Sinatra は proc をゲッターの本体そのものにするため
      # 参照するたびに Tantiny::Index を開き直すことになる。
      set :search_index_path , File.join(Lokka.root, 'tmp', 'index')
    end

    set :asset_version,
      begin
        revision_time_file = File.join(Lokka.root, 'REVISION_TIME')
        if File.exist?(revision_time_file)
          File.read(revision_time_file).strip
        end
      end

    after '/' do
      cache_control :public, max_age: 5.minutes
    end

    get '/index.atom' do
      @posts = Post.preload(:category, :user).
        published.
        page(params[:page] || 1).
        per(20).
        order(@site.default_order)
      @posts = apply_continue_reading(@posts)

      content_type 'application/atom+xml', charset: 'utf-8'
      builder :'plugin/lokka-portalshit_patches/public/lokka/index'
    end

    get '/sitemap.xml' do
      @categories = Category.joins(:entries).where(entries: { draft: false }).distinct
      content_type 'application/xml', charset: 'utf-8'
      builder :'plugin/lokka-portalshit_patches/public/lokka/sitemap'
    end

    get '/sitemap/categories/:slug' do
      category = Category.get_by_fuzzy_slug(params[:slug]) || halt(404)
      @posts = category.entries.published.
        includes(:category, :tags, :user).
        order(@site.default_order)
      @posts = apply_continue_reading(@posts)
      content_type 'application/xml', charset: 'utf-8'
      builder :'plugin/lokka-portalshit_patches/public/lokka/categories/sitemap'
    end

    get '/search.json' do
      return if params[:query].blank?
      search_result = Search.query(params[:query])
      posts = Post.published.joins(:category).where(id: search_result).
        sort_by {|post| search_result.index(post.id.to_s) }
      posts_hash = posts.each_with_object([]) {|post, result|
        result << {
          id: post.id,
          title: post.title,
          link: post.link,
          created_at: post.created_at
        }
      }
      cache_control :public, :must_revalidate, max_age: 5.minutes
      content_type :json
      posts_hash.to_json
    end

    get '/categories' do
      @theme_types << :entries

      categories = sorted_categories
      @latest_posts = latest_posts_by_category(categories)
      @category_cards = categories.select { |category| @latest_posts.key?(category.id) }.
        sort_by { |category| [@latest_posts[category.id].created_at, @latest_posts[category.id].id] }.reverse
      @entry_lengths = published_post_counts_by_category

      @title = %Q(#{t('categories')} - #{@site.title})

      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: t('categories') }]

      render_detect :categories
    end
  end
end
