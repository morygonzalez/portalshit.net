module Lokka
  module TwitterCard
    def self.registered(app); end
  end

  module Helpers
    def twitter_card(resource)
      photo_identifier = /写真|photo|foto/
      case
      when !resource.instance_of?(Entry) && !resource.instance_of?(Post)
        <<-EOS.strip_heredoc
          <meta name="twitter:card" content="summary">
          <meta name="twitter:site" content="#{@site.title}">
          <meta name="twitter:creator" content="@#{User.first.name}">
          <meta name="twitter:title" content="#{@site.title}">
          <meta name="twitter:description" content="#{@site.meta_description}" />
          <meta name="twitter:image" content="#{detect_image_from()}" />
          <meta name="twitter:url" content="#{@request.scheme}://#{@request.host}/" />
        EOS
      when resource.category.title =~ photo_identifier
        <<-EOS.strip_heredoc
          <meta name="twitter:card" content="summary_large_image">
          <meta name="twitter:site" content="#{@site.title}">
          <meta name="twitter:creator" content="@#{resource.user.name}">
          <meta name="twitter:title" content="#{resource.title}">
          <meta name="twitter:description" content="#{extract_description_from(resource)}" />
          <meta name="twitter:image:src" content="#{detect_image_from(resource)}">
        EOS
      else
        <<-EOS.strip_heredoc
          <meta name="twitter:card" content="summary" />
          <meta name="twitter:site" content="#{@site.title}">
          <meta name="twitter:creator" content="@#{resource.user.name}">
          <meta name="twitter:title" content="#{resource.title}">
          <meta name="twitter:description" content="#{extract_description_from(resource)}" />
          <meta name="twitter:image" content="#{detect_image_from(resource)}" />
          <meta name="twitter:url" content="#{@request.scheme}://#{@request.host}/#{resource.link}" />
        EOS
      end
    end

    def detect_image_from(resource=nil)
      if resource.respond_to?(:body) && resource.body =~ /(https?:\/\/[\w\/:%#\$&\?\(\)~\.=\+\-]+?\.(?:png|jpe?g|gif))/
        $1
      else
        "#{@request.scheme}://#{@request.host}#{@theme.path}/screenshot.png"
      end
    end

    def extract_description_from(entry)
      truncate(strip_tags(entry.body).strip.gsub(/[\t]+/, ' ').gsub(/[\r\n]/, ''), length: 200)
    end
  end
end
