# frozen_string_literal: true

require 'net/http'

class Entry < ActiveRecord::Base
  has_many :comments
  has_many :approved_comments, -> { approved }, class_name: 'Comment'
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

  attr_accessor :tag_collection, :generate_or_update_summary, :auto_generate_tags

  after_save :update_fields
  after_save :send_ping_to_pubsubhubbub
  after_commit :purge_atom_cache

  default_scope { order('entries.created_at DESC') }
  scope :published,   -> { where("publish_at IS NOT NULL AND publish_at <= ?", Time.current) }
  scope :unpublished, -> { where(publish_at: nil) }
  scope :scheduled,   -> { where("publish_at IS NOT NULL AND publish_at > ?", Time.current) }
  scope :posts,       -> { where(type: 'Post') }
  scope :pages,       -> { where(type: 'Page') }
  scope :recent,
        ->(count = 5) { limit(count) }
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
      return '%s...' % summary[0..120] if summary.length > 120
      summary
    else
      long_description
    end
  end

  def draft?
    publish_at.nil?
  end

  def scheduled?
    publish_at.present? && publish_at > Time.current
  end

  def published?
    publish_at.present? && publish_at <= Time.current
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

  def send_ping_to_pubsubhubbub
    if Lokka.production? && published?
      system("curl -s https://pubsubhubbub.appspot.com/ -d 'hub.mode=publish&hub.url=https://portalshit.net/index.atom' -X POST")
    end
  end

  def purge_atom_cache
    return unless published?

    Net::HTTP.start('localhost', 80) do |http|
      req = Net::HTTP::Get.new('/index.atom')
      req['Cache-Purge'] = 'true'
      http.request(req)
    end
  rescue StandardError => e
    ActiveRecord::Base.logger&.warn "Failed to purge atom cache: #{e.message}"
  end
end
