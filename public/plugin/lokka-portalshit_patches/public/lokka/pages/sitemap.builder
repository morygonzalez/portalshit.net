# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  %w[/popular /about /morygonzalez].each do |path|
    xml.url do
      xml.loc "#{request.base_url}#{path}"
    end
  end
end
