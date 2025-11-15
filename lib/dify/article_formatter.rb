# frozen_string_literal: true

require 'cgi'
require 'nokogiri'

module Dify
  class ArticleFormatter
    attr_reader :base_url

    def initialize(base_url: '')
      @base_url = (base_url || '').to_s
    end

    def article_hash(post)
      {
        id:      safe_send(post, :id),
        title:   safe_send(post, :title).to_s,
        date:    safe_send(post, :created_at)&.to_date&.to_s,
        tags:    extract_tags(post),
        slug:    safe_send(post, :slug)&.to_s,
        url:     build_url_for(post),
        source:  'portalshit.net',
        content: extract_plain_text_from_html(extract_html(post))
      }
    end

    def compose_year_text(posts, delimiter: "\n---\n\n")
      blocks = posts.map { |hash| compose_article_block(hash) }
      return blocks.join("\n") if delimiter.nil?

      blocks.join(delimiter)
    end

    def compose_article_block(hash)
      <<~TXT
      === ARTICLE START id:#{hash[:id]} ===
      [published_at: #{hash[:date]}]
      Title: #{hash[:title]}
      URL: #{hash[:url]}
      tags: #{Array(hash[:tags]).join(', ')}

      #{hash[:content]}
      TXT
    end

    def build_url_for(post)
      candidate =
        if post.respond_to?(:link) && post.link
          post.link.to_s
        elsif post.respond_to?(:slug) && post.slug
          "/#{post.slug}"
        else
          "/posts/#{safe_send(post, :id)}"
        end

      safe_join_url(base_url, candidate)
    end

    private

    def extract_html(post)
      if post.respond_to?(:raw_body)
        post.raw_body
      elsif post.respond_to?(:body)
        post.body.to_s
      else
        ''
      end
    end

    def extract_plain_text_from_html(html_src)
      html = html_src.to_s
      html = html.gsub(/<\s*br\s*\/?>/i, "\n").gsub(/\u00A0/, ' ')
      doc  = Nokogiri::HTML::DocumentFragment.parse(html)
      text = doc.xpath('.//text()').map(&:text).join
      text = CGI.unescapeHTML(text)
      text = text.gsub(/\r\n?/, "\n").strip
      text = text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      text = text.gsub(/[^\P{Cntrl}\t\n]/, '')
      text
    end

    def extract_tags(post)
      return [] unless post.respond_to?(:tags)

      Array(post.tags).map do |tag|
        tag.respond_to?(:name) ? tag.name : tag.to_s
      end
    end

    def safe_send(object, method_name)
      object.respond_to?(method_name) ? object.public_send(method_name) : nil
    end

    def safe_join_url(base, maybe_path)
      return nil if base.to_s.empty? && maybe_path.to_s.empty?

      path = maybe_path.to_s
      if path.start_with?('http://', 'https://')
        path
      else
        sanitized_base = base.to_s.sub(%r{/\z}, '')
        path = "/#{path}" unless path.start_with?('/')
        sanitized_base.empty? ? path : "#{sanitized_base}#{path}"
      end
    end
  end
end
