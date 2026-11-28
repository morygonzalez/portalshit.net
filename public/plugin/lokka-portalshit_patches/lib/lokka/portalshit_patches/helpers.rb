module Lokka
  module Helpers
    def sorted_categories
      @categories ||= Category.find(
        Category.joins(:entries).where(entries: Post.published).
          group(:id).order(count_entries_id: :desc).count(:'entries.id').
          keys
      )
    end

    def latest_posts_by_category(categories)
      Post.published.includes(:category).where(category_id: categories.map(&:id)).where(<<~SQL, 'Post', false).index_by(&:category_id)
        NOT EXISTS (
          SELECT 1 FROM entries newer
          WHERE newer.category_id = entries.category_id
            AND newer.type = ? AND newer.draft = ?
            AND (newer.created_at > entries.created_at
              OR (newer.created_at = entries.created_at AND newer.id > entries.id))
        )
      SQL
    end

    def published_post_counts_by_category
      Post.published.reorder(nil).group(:category_id).count
    end

    def bread_crumb
      return '' if @bread_crumbs.nil? || @bread_crumbs.empty?

      bread_crumb =
        @bread_crumbs[0..-2].each.with_index(1).
        inject('<ol itemscope itemtype="http://schema.org/BreadcrumbList">') do |html, (bread, index)|
          html += <<~RUBY_HTML
                      <li itemprop="itemListElement" itemscope itemtype="http://schema.org/ListItem">
                        <a itemscope itemtype="http://schema.org/Thing" itemprop="item" href="#{bread[:link]}" id="#{bread[:link]}">
                          <span itemprop="name">#{bread[:name]}</span>
                        </a>
                        <meta itemprop="position" content="#{index}" />
                      </li>
          RUBY_HTML
        end + <<~RUBY_HTML
            <li itemprop="itemListElement" itemscope itemtype="http://schema.org/ListItem">
              <span itemscope itemtype="http://schema.org/Thing" itemprop="item" id="#{@bread_crumbs[-1][:link]}">
                <span itemprop="name">#{h(@bread_crumbs[-1][:name])}</span>
              </span>
              <meta itemprop="position" content="#{@bread_crumbs.length}" />
            </li>
          </ol>
        RUBY_HTML
        bread_crumb.html_safe
    end

    def color_mode
      request.cookies['prefers-color-scheme']
    end

    # `<meta name="color-scheme">` 用の値。
    # スタイルシートが読み込まれる前のキャンバス背景・スクロールバーの色を
    # 確定させ、初回描画時のチラつきを抑える。
    # 明示指定がない場合は OS 設定に従わせる。
    def color_scheme
      case color_mode
      when 'dark-mode' then 'dark'
      when 'light-mode' then 'light'
      else 'light dark'
      end
    end

    def portalshit_manifest
      @portalshit_manifest ||= \
        begin
          file_path = File.join(Lokka.root, 'public/theme/portalshit/scripts', 'manifest.json')
          content = File.open(file_path).read
          manifest = JSON.parse(content)
        end
    end

    def portalshit_javascript_path(file_name)
      "#{@theme.path}/scripts/#{portalshit_manifest[file_name]}"
    end

    def article_slug_suggestion_path?(path)
      return false if path.match?(%r{\A/(?:admin|api)(?:/|\z)})

      slug = path.delete_prefix('/')
      if slug.include?('/') || slug.include?('.')
        permalink = custom_permalink_parse(path) if custom_permalink?
        return false unless permalink

        date_parts = permalink.slice(:year, :monthnum, :month, :day, :hour, :minute, :min, :second, :sec).values
        return false unless date_parts.all? { |part| part.match?(/\A[0-9]+\z/) }

        slug = permalink[:slug]
      end

      slug&.match?(/\A[a-zA-Z0-9_-]+\z/) && !slug.match?(/\A[0-9]+\z/)
    end

    def not_found_candidate
      all_slugs = Entry.published.where.not(slug: [nil, '']).pluck(:slug)
      slugs = all_slugs.reject { |slug| slug.match?(/\A\d+\z/) }
      current_slug = request.path_info.split('/').last
      return if current_slug.blank?

      candidates = DidYouMean::SpellChecker.new(dictionary: slugs).correct(current_slug)
      return unless candidates.one?

      entries = Entry.published.where(slug: candidates).limit(2).to_a
      entries.first if entries.one?
    end

    def popular_keywords
      @popular_keywords ||= PopularKeywords.keywords
    rescue => e
      logger.error "PopularKeywords error: #{e.class}: #{e.message}" if respond_to?(:logger)
      []
    end

    def asset_timestamp(file_path)
      return nil if file_path =~ /\?/

      version = settings.asset_version
      return nil if version.nil? || version.empty?

      "?#{version}"
    end
  end
end
