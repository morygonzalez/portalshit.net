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
          'data-bg-light-image': "light-#{light_image['name']}",
          'data-bg-light-description': light_image['description']
        }
      }

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
      @categories = Category.includes(:entries).where(entries: { draft: false }).all
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

      query = <<~SQL
        select entries.id
        from entries
        inner join (
          select
          category_id,
            group_concat(id order by created_at desc) as entry_ids,
            count(id) as entry_count,
            max(created_at) as last_created_at
          from entries
          where entries.draft = false
          group by category_id
        ) as grouped_entries
        on grouped_entries.category_id = entries.category_id and find_in_set(id, entry_ids) between 1 and 4
        inner join categories on categories.id = entries.category_id
        order by last_created_at desc, entries.id desc;
      SQL
      entry_ids = ActiveRecord::Base.connection.select_all(query).rows.flatten
      entries = Entry.includes(:category, :user, :tags, :approved_comments).where(id: entry_ids)
      @entries_group_by_category = entries.each_with_object({}) {|entry, result|
        result[entry.category] ||= []
        result[entry.category] << entry
      }

      @title = %Q(#{t('categories')} - #{@site.title})

      @bread_crumbs = [{ name: t('home'), link: '/' },
                       { name: t('categories') }]

      render_detect :categories
    end
  end
end
