module Lokka
  class App
    configure do
      bg_images = YAML.load_file(File.join(File.dirname(__FILE__), 'header-bg.yml'))
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
  end

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

    def portalshit_manifest
      @portalshit_manifest ||= \
        begin
          file_path = File.join(File.dirname(__FILE__), 'scripts', 'manifest.json')
          content = File.open(file_path).read
          manifest = JSON.parse(content)
        end
    end

    def portalshit_javascript_path(file_name)
      "#{@theme.path}/scripts/#{portalshit_manifest[file_name]}"
    end

    def show_auto_ads?
      return false if entry? && @entry.created_at > Time.current - 2.day
      true
    end
  end
end
