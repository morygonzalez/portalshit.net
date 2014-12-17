module Lokka
  module TwitterCard
    def self.registered(app)
      app.before do
        photo_identifier = /写真|photo|foto/
        twitter_card = \
          case
          when defined?(@entry).nil?
            <<-EOS
              <meta name="twitter:card" content="summary">
              <meta name="twitter:site" content="#{@site.title}">
              <meta name="twitter:creator" content="@#{User.first.name}">
              <meta name="twitter:title" content="#{@site.title}">
              <meta name="twitter:description" content="#{@site.meta_description}" />
              <meta name="twitter:image" content="#{detect_image_from()}" />
              <meta name="twitter:url" content="#{@request.scheme}://#{@request.host}/" />
            EOS
          when @entry.category.title =~ photo_identifier
            <<-EOS
              <meta name="twitter:card" content="summary_large_image">
              <meta name="twitter:site" content="#{@site.title}">
              <meta name="twitter:creator" content="@#{@entry.user.name}">
              <meta name="twitter:title" content="#{@entry.title}">
              <meta name="twitter:description" content="#{extract_description_from(@entry)}" />
              <meta name="twitter:image:src" content="#{detect_image_from(@entry)}">
            EOS
          else
            <<-EOS
              <meta name="twitter:card" content="summary" />
              <meta name="twitter:site" content="#{@site.title}">
              <meta name="twitter:creator" content="@#{@entry.user.name}">
              <meta name="twitter:title" content="#{@entry.title}">
              <meta name="twitter:description" content="#{extract_description_from(@entry)}" />
              <meta name="twitter:image" content="#{detect_image_from(@entry)}" />
              <meta name="twitter:url" content="#{@entry.link}" />
            EOS
          end
        content_for :header do
          twitter_card
        end
      end
    end
  end

  module Helpers
    def detect_image_from(resource=nil)
      if resource.respond_to?(:body) && resource.body =~ /(https?\/\/(.+)\.(?:png|jpe?g|gif))/
        $1
      else
        "#{@request.scheme}://#{@request.host}#{@theme.path}/screenshot.png"
      end
    end

    def extract_description_from(entry)
      truncate(entry.body, 200)
    end
  end
end
