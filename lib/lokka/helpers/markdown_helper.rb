# frozen_string_literal: true

require 'reverse_markdown'

module Lokka
  module MarkdownHelper
    private

    def markdown_requested?
      vary = response.headers['vary'].to_s.split(',').map(&:strip)
      unless vary.any? { |field| field == '*' || field.casecmp?('Accept') }
        response.headers['vary'] = (vary + ['Accept']).join(', ')
      end

      qualities = request.env['HTTP_ACCEPT'].to_s.split(',').each_with_object({}) do |range, types|
        type, *parameters = range.split(';').map { |part| part.strip.downcase }
        quality = parameters.find { |param| param.match?(/\Aq\s*=/) }
        weight = quality ? Float(quality.split('=', 2).last, exception: false) : 1.0
        next unless weight && (0..1).cover?(weight)

        types[type] = [types.fetch(type, 0), weight].max
      end
      markdown = qualities.fetch('text/markdown', 0)
      html = qualities.values_at('text/html', 'text/*', '*/*').compact.first || 0
      markdown.positive? && markdown >= html
    end

    def render_markdown(html)
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css('script, style, template, noscript, iframe, nav, [hidden]').remove
      content_type 'text/markdown', charset: 'utf-8'
      ReverseMarkdown.convert(fragment, github_flavored: true, unknown_tags: :bypass).strip + "\n"
    end

    def render_markdown_entries(posts, links: [])
      articles = posts.map do |post|
        "<h2>#{markdown_link(post.title, post.link)}</h2>\n#{post.body}"
      end
      pagination = paginate(posts)
      # Only keep the links from the pagination controls.
      page_links = Nokogiri::HTML5.fragment(pagination.to_s).css('a').map(&:to_html).join(' ')
      navigation = markdown_link_list(links) if links.any?
      render_markdown(["<h1>#{h(@title)}</h1>", navigation, *articles, "<p>#{page_links}</p>"].compact.join("\n"))
    end

    def render_markdown_archive_links(links)
      render_markdown("<h1>#{h(@title)}</h1>\n#{markdown_link_list(links)}")
    end

    def markdown_link_list(links)
      items = links.map { |title, path| "<li>#{markdown_link(title, path)}</li>" }.join
      "<ul>#{items}</ul>"
    end

    def markdown_link(title, path)
      %(<a href="#{h(path)}">#{h(title)}</a>)
    end
  end
end
