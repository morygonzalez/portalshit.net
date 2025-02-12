module Lokka
  module Helpers
    def sorted_categories
      @categories ||= Category.find(
        Category.joins(:entries).where(entries: Post.published).
          group(:id).order(count_entries_id: :desc).count(:'entries.id').
          keys
      )
    end

    def bread_crumb
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

    def not_found_candidates
      @not_found_candidates ||=
        begin
          slugs = Entry.published.where.not('slug REGEXP ?', '^[0-9]+$').pluck(:slug)
          spell_checker = DidYouMean::SpellChecker.new(dictionary: slugs)
          current_slug = request.path_info.split('/').last
          slug_candidate = spell_checker.correct(current_slug)
          Entry.published.where(slug: slug_candidate)
        end
    end

    def popular_keywords
      @popular_keywords ||= PopularKeywords.keywords
    end
  end
end
