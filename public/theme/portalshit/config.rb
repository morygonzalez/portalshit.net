class Lokka::App
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
