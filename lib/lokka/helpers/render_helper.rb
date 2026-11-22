# frozen_string_literal: true

module Lokka
  module RenderHelper
    def render_detect(*names)
      options = names.last.is_a?(Hash) ? names.pop : {}
      render_detect_with_options(*names, **options)
    end

    def render_detect_with_options(*names, **options)
      ret = ''
      options[:layout] = 'layout'
      names.flatten.each do |name|
        out = render_any(name, **options)
        unless out.blank?
          ret = out
          break
        end
      end

      return ret if ret.present?

      raise Lokka::NoTemplateError, "Template not found. #{[names.join(', ')]}"
    end

    def partial(name, **options)
      options[:layout] = false
      render_any(name, **options)
    end

    def render_any(name, **options, &block)
      ret = ''
      templates = settings.supported_templates + settings.supported_stylesheet_templates +
        settings.supported_javascript_templates
      templates.each do |ext|
        out = rendering(ext, name, **options, &block)
        out&.force_encoding(Encoding.default_external)
        unless out.blank?
          ret = out
          break
        end
      end
      ret
    end

    def rendering(ext, name, **options, &block)
      options[:views] ||= "#{settings.views}/theme/#{@theme.name}"
      path = "#{options[:views]}/#{name}"

      send(ext.to_sym, name.to_sym, **options) if File.exist?("#{path}.#{ext}")
    end

    private

    def resolve_layout(layout, options = {})
      views = options[:views]
      return super unless layout == 'layout' && views == "#{settings.views}/theme/#{@theme&.name}"

      # Padrino's layout cache omits the views directory, so themes with
      # different template engines can otherwise reuse each other's layout.
      rendering_options = [layout, content_type || :html, locale]
      settings.cache_template_path([views, *rendering_options]) do
        selected = select_template(glob_templates(views, layout), *rendering_options)
        raise Padrino::Rendering::TemplateNotFound, "Layout '#{layout}' not found in '#{views}'" unless selected

        selected
      end
    end
  end
end
