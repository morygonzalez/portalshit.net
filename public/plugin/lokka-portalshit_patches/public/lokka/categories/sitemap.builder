port = request.port == 80 ? '' : ':' + request.port.to_s
base_url = request.scheme + '://' + request.host + port

xml.instruct! :xml, version: '1.0'
xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
  @posts.each do |post|
    xml.url do
      xml.loc base_url + post.link
      xml.lastmod post.updated_at.to_s
    end
  end
end
