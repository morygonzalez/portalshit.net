# frozen_string_literal: true

require 'json'
require 'net/http'

class Entry < ActiveRecord::Base
  # SQLite does not expose a TEXT byte limit; match the production MEDIUMTEXT capacity.
  DEFAULT_BODY_BYTE_LIMIT = 16_777_215

  ATOM_FEED_URL = 'https://portalshit.net/index.atom'
  class FeedRequestError < StandardError; end
  private_constant :ATOM_FEED_URL, :FeedRequestError

  has_many :comments
  has_many :public_comments, -> { publicly_visible }, class_name: 'Comment'
  has_many :approved_comments, -> { publicly_visible }, class_name: 'Comment'
  has_many :taggings, as: :taggable
  has_many :tags, through: :taggings
  has_many :similarities
  has_many :similar_entries, through: :similarities
  has_one  :entry_embedding
  has_one  :entry_summary

  belongs_to :user
  belongs_to :category

  validates :title, presence: true
  validates :slug, uniqueness: true,
                   format: %r{\A[_/0-9a-zA-Z-]+\z}, allow_blank: true

  validate :validate_confliction
  validate :validate_body_byte_length

  attr_accessor :tag_collection, :generate_or_update_summary, :auto_generate_tags

  after_save :update_fields
  after_save :mark_atom_feed_changed
  after_destroy :mark_atom_feed_removed
  after_commit :purge_atom_cache_and_notify
  after_rollback { @atom_feed_changed = false }

  default_scope { order('entries.created_at DESC') }
  scope :published,   -> { where(draft: false) }
  scope :unpublished, -> { where(draft: true) }
  scope :posts,       -> { where(type: 'Post') }
  scope :pages,       -> { where(type: 'Page') }
  scope :recent,
        ->(count = 5) { limit(count) }
  scope :created_around_today,
        ->(date = Time.current.to_date) {
          from = date - 3.days
          to = date + 3.days
          month_day = if connection.adapter_name =~ /Mysql/i
                        "DATE_FORMAT(entries.created_at, '%m%d')"
                      else
                        "strftime('%m%d', entries.created_at)"
                      end
          year = if connection.adapter_name =~ /Mysql/i
                   'YEAR(entries.created_at)'
                 else
                   "CAST(strftime('%Y', entries.created_at) AS INTEGER)"
                 end

          relation = if from.year == to.year
                       where("#{month_day} BETWEEN ? AND ?", from.strftime('%m%d'), to.strftime('%m%d'))
                     else
                       where("#{month_day} >= ? OR #{month_day} <= ?", from.strftime('%m%d'), to.strftime('%m%d'))
                     end

          relation.where("#{year} < ?", date.year)
        }
  scope :between_a_year,
        ->(time) {
          where(created_at: time.beginning_of_year..time.end_of_year)
        }
  scope :between_a_month,
        ->(time) {
          where(created_at: time.beginning_of_month..time.end_of_month)
        }
  scope :search,
        ->(words) {
          return all if words.blank?
          if words =~ /\Acategory:(.+?)(?:\s|\z)/
            category_name = $1
            where(id: joins(:category).where(categories: { title: category_name }).select('entries.id'))
          elsif words =~ /\Atags?:(.+)/
            tag_names = $1.split(",").map(&:strip)
            where(id: joins(:tags).where(tags: { name: tag_names }).select('entries.id'))
          else
            if connection.adapter_name =~ /Mysql/i
              where('MATCH (entries.title, entries.body) AGAINST (? in BOOLEAN MODE)', words)
            else
              where('entries.title LIKE :q OR entries.body LIKE :q', q: "%#{words}%")
            end
          end
        }

  def self.body_byte_limit
    columns_hash.fetch('body').limit || DEFAULT_BODY_BYTE_LIMIT
  end

  def self.get_by_fuzzy_slug(id_or_slug)
    where(slug: id_or_slug).first || where(id: id_or_slug).first
  end

  def raw_body
    attributes['body']
  end

  def long_body
    @long_body ||= Markup.use_engine(markup, raw_body)
  end
  alias body long_body

  def short_body
    @short_body ||= long_body&.sub(
      /<!-- ?more ?-->.*/m, %(<a href="#{link}">#{I18n.t('continue_reading')}</a>)
    )&.html_safe
  end

  def description
    src = long_body&.tr("\n", '')
    return if src.nil?

    desc = src =~ %r{<p[^>]*>(.+?)</p>}i ? Regexp.last_match(1) : src[0..50]
    desc.gsub(%r{<[^/]+/>}, ' ').gsub(%r{</[^/]+>}, ' ').gsub(/<[^>]+>/, '').html_safe
  end

  def summary_or_description
    if summary.present?
      return '%s...' % summary[0..200] if summary.length > 200
      summary
    else
      long_description
    end
  end

  def draft?
    draft
  end

  def published?
    !draft?
  end

  def fuzzy_slug
    slug.blank? ? id : slug
  end

  def link
    "/#{fuzzy_slug}"
  end

  def edit_link
    "/admin/#{self.class.to_s.tableize}/#{id}/edit"
  end

  def tag_list
    @tag_list ||= tags.pluck(:name)
  end

  def tag_collection
    tag_list.join(', ')
  end

  def tag_collection=(values)
    regexp = /[^[:word:][:blank:]]/iu
    new_tag_list = values.to_s.split(',').map do |name|
      name.force_encoding(Encoding.default_external).gsub(regexp, '').strip
    end
    self.tags = new_tag_list.uniq.map {|name| Tag.find_or_create_by(name: name) }
  end

  def tags_to_html
    html = '<ul class="tags">'
    tags.each do |tag|
      html += %(<li class="tag"><a href="#{tag.link}">#{tag.name}</a></li>)
    end
    html += '</ul>'
    html.html_safe
  end

  # custom fields
  attr_writer :fields

  def update_fields
    return unless @fields

    @fields.each do |k, v|
      send("#{k}=", v)
    end
  end

  def validate_confliction
    return true unless id

    if @updated_at == self.class.find(id).updated_at
      true
    else
      [false, 'The entry is updated while you were editing']
    end
  end

  def method_missing(method, *args)
    attribute = method.to_s
    if attribute.match?(/=$/)
      column = attribute[0, attribute.size - 1]
      field_name = FieldName.where(name: column).first
      field = Field.where(entry_id: id, field_name_id: field_name.id).first
      if field
        field.value = args.first
      else
        field = Field.new(entry_id: id, field_name_id: field_name.id, value: args.first)
      end
      field.save
    else
      field_name = FieldName.where(name: attribute).first
      field = Field.where(entry_id: id, field_name_id: field_name.id).first
      field.try(:value)
    end
  end

  private

  def validate_body_byte_length
    limit = self.class.body_byte_limit
    bytes = raw_body.to_s.bytesize
    return if bytes <= limit

    errors.add(:body, I18n.t('entry.errors.body_too_large', limit: limit, bytes: bytes))
  end

  def send_ping_to_pubsubhubbub
    uri = URI('https://pubsubhubbub.appspot.com/')
    request = Net::HTTP::Post.new(uri)
    request.set_form_data('hub.mode' => 'publish', 'hub.url' => ATOM_FEED_URL)
    response = send_feed_request(uri, request)
    raise FeedRequestError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end

  def purge_cloudflare_atom_cache
    zone_id = ENV['CLOUDFLARE_ZONE_ID'].presence
    token = ENV['CLOUDFLARE_API_TOKEN'].presence
    return unless zone_id && token

    uri = URI("https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request.content_type = 'application/json'
    request.body = JSON.generate(files: [ATOM_FEED_URL])

    response = send_feed_request(uri, request)
    raise FeedRequestError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body)
    raise FeedRequestError, 'API success was not true' unless result.is_a?(Hash) && result['success'] == true
  end

  def send_feed_request(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 5, write_timeout: 5) do |http|
      http.request(request)
    end
  end

  def mark_atom_feed_changed
    return unless is_a?(Post)

    @atom_feed_changed ||= (draft == false && saved_changes?) ||
                           (!previously_new_record? && saved_change_to_draft? && draft_before_last_save == false)
  end

  def mark_atom_feed_removed
    @atom_feed_changed = true if is_a?(Post) && attribute_in_database('draft') == false
  end

  def purge_atom_cache_and_notify
    changed = @atom_feed_changed
    @atom_feed_changed = false
    return unless Lokka.production? && changed

    operation = 'Cloudflare Atom cache purge'
    purge_cloudflare_atom_cache
    operation = 'PubSubHubbub Atom notification'
    send_ping_to_pubsubhubbub
  rescue StandardError => e
    # Exception messages and API bodies may contain request credentials.
    detail = e.is_a?(FeedRequestError) ? e.message : e.class
    message = "#{operation} failed for entry #{id} (#{detail})"
    logger = ActiveRecord::Base.logger
    logger ? logger.warn(message) : warn(message)
  end
end
