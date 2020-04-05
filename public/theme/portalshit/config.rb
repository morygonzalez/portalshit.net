class Lokka::App
  configure do
    bg_images = YAML.load_file(File.join(File.dirname(__FILE__), 'header-bg.yml'))
    set :header_bg_params, -> {
      dark_image = bg_images['dark'].sample
      light_image = bg_images['light'].sample
      {
        'data-bg-dark-image': "dark-#{dark_image['name']}",
        'data-bg-dark-location': dark_image['location'],
        'data-bg-light-image': "light-#{light_image['name']}",
        'data-bg-light-location': light_image['location']
      }
    }
  end
end
