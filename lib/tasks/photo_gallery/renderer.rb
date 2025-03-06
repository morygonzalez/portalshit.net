module PhotoGallery
  class Renderer
    def initialize(image_hashes)
      @image_hashes = image_hashes
    end

    def render
      template = File.read(File.join(__dir__, 'template.erb'))
      ERB.new(template, trim_mode: '-').result(binding)
    end
  end
end
