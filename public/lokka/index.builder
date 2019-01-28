# frozen_string_literal: true

def expand_associate_link(body)
  expander = ExpandAmazonAssociateLink.new(body)
  expander.expand_associate_link
end

class ExpandAmazonAssociateLink
  attr_reader :body

  def initialize(body)
    @body = body
  end

  def expand_associate_link
    matches = body.scan(/<!--\s(?:ASIN|ISBN)=(.+?)\s-->/).flatten
    return body if matches.blank?

    matches.each do |match|
      item = AmazonItem.new(match)
      partial = Formatter.new(item).format
      body.gsub!(/<!--\s(?:ASIN|ISBN)=#{match}\s-->/, partial)
    end

    body
  end
end

class Formatter
  def initialize(item)
    @item = item
  end

  def format
    <<~HTML
      <div class="amazon">
        <a href="#{@item.link}"><img src="#{@item.image}" /></a>
        <ul>
          <li><a href="#{@item.link}">#{@item.title}</a></li>
          <li>#{@item.manufacturer}</li>
          <li>#{@item.author}</li>
          <li><a href="#{@item.link}">#{@item.price}</a></li>
        </ul>
      </div>
    HTML
  end
end

class AmazonItem
  attr_reader :item_id

  def initialize(item_id)
    @item_id = item_id
  end

  def associate_item
    @associate_item ||= Lokka::AmazonAssociate::Fetcher.new(item_id)
  end

  def body
    @body ||= associate_item.body
  end

  def item
    @item ||= JSON.parse(body).dig('ItemLookupResponse', 'Items', 'Item') || {}
  end

  def attributes
    @attributes ||= item['ItemAttributes'] || {}
  end

  def title
    @title ||= attributes['Title']
  end

  def link
    @link ||= item['DetailPageURL']
  end

  def image_set
    @image_set ||= item['ImageSets'] ? item.dig('ImageSets', 'ImageSet') : false
  end

  def image
    @image ||= case
               when item['LargeImage']
                 item.dig('LargeImage', 'URL')
               when image_set && image_set.length > 1
                 item.dig('ImageSets', 'ImageSet', 'URL')
               when image_set && image_set.length == 1
                 image_set.dig('LargeImage', 'URL')
               else
                 '/plugin/lokka-amazon_associate/assets/no-image.png'
               end
  end

  def manufacturer
    @manufacturer ||= attributes['Brand'] || attributes['Manufacturer'] || attributes['Studio']
  end

  def price
    @price ||= case
               when item.dig('OfferSummary', 'LowestNewPrice')
                 item.dig('OfferSummary', 'LowestNewPrice', 'FormattedPrice')
               when item.dig('OfferSummary', 'LowestUsedPrice')
                 item.dig('OfferSummary', 'LowestUsedPrice', 'FormattedPrice')
               when item.dig('OfferSummary', 'LowestCollectiblePrice')
                 item.dig('OfferSummary', 'LowestCollectiblePrice', 'FormattedPrice')
               else
                 'Amazon で確認';
               end
  end

  def author
    @author ||= begin
                  authors = []

                  authors.push(attributes['Creator'])  if attributes['Creator'].present?
                  authors.push(attributes['Author'])   if attributes['Author'].present?
                  authors.push(attributes['Director']) if attributes['Director'].present?
                  authors.push(attributes['Actor'])    if attributes['Actor'].present?
                  authors.push(attributes['Artist'])   if attributes['Artist'].present?

                  authors.flatten.join(', ')
                end
  end
end

port = [443, 80].include?(request.port) ? '' : ':' + request.port.to_s
base_url = request.scheme + '://' + request.host + port

xml.instruct! :xml, version: '1.0'
xml.feed(xmlns: 'http://www.w3.org/2005/Atom') do
  xml.id      base_url + '/'
  xml.title   @site.title
  xml.updated @posts.first.updated_at.to_s
  xml.link    type: 'text/html', rel: 'alternate', href: base_url + '/'
  xml.link    type: 'application/atom+xml', ref: 'self', href: base_url + '/index.atom'
  xml.link    rel: 'hub', href: 'https://pubsubhubbub.appspot.com/'

  @posts.each do |post|
    xml.entry do
      xml.id        'tag:' + base_url.gsub('http://', '') + ',' + post.created_at.to_s
      xml.title     post.title, type: 'html'
      xml.published post.created_at.to_s
      xml.updated   post.updated_at.to_s
      xml.link      type: 'html', rel: 'alternate', href: base_url + post.link
      xml.content   expand_associate_link(post.body), type: 'html'
      xml.author do
        xml.name post.user.nil? ? '' : post.user.name
      end
    end
  end
end
