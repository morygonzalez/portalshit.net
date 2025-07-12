module PhotoGallery
  class Renderer
    def initialize(images)
      @cover = images.find {|item| item[:keywords] =~ /cover/i }
      @images = images.delete_if {|item| item[:s3_filename] == @cover[:s3_filename] }
    end

    def render
      template = File.read(File.join(__dir__, 'template.erb'))
      ERB.new(template, trim_mode: '-').result(binding)
    end
  end
end
