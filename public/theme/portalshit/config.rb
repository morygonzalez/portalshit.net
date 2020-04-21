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

    # before do
    #   query = <<~SQL
    #     SELECT categories.slug, categories.title, COUNT(1) as count
    #     FROM categories
    #     INNER JOIN entries ON entries.category_id = categories.id
    #     WHERE entries.type = 'Post' AND entries.draft = FALSE
    #     GROUP BY categories.slug, categories.title
    #     ORDER BY count DESC;
    #   SQL
    #   @categories = Category.repository.adapter.select(query).map(&:to_h)
    # end
  end
end

