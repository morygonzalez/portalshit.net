port = request.port == 80 ? '' : ':' + request.port.to_s
base_url = request.scheme + '://' + request.host + port

xml.instruct! :xml, version: '1.0'
xml.sitemapindex(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  @categories.each do |category|
    xml.sitemap do
      xml.loc "#{base_url}/sitemap/categories/#{category.slug}"
      xml.lastmod category.entries.published.first.updated_at.to_s
    end
  end
end
