# frozen_string_literal: true

class Comment < ActiveRecord::Base
  MODERATED = 0
  APPROVED  = 1
  SPAM      = 2

  belongs_to :entry

  validates :name, presence: true
  validates :body, presence: true
  validates :email, presence: true
  validates_length_of :email, in: (1..40)
  validates_length_of :homepage, in: (0..255), if: ->(record) { record.homepage.present? }

  default_scope -> { order('created_at DESC') }

  validate :keep_private_comments_private

  scope :publicly_visible, -> { where(status: APPROVED, private: false) }
  scope :private_comments, -> { where(private: true) }
  scope :moderated, -> { where(status: MODERATED) }
  scope :approved,  -> { where(status: APPROVED) }
  scope :spam,      -> { where(status: SPAM) }
  scope :recent,
        ->(count = 5) { publicly_visible.limit(count) }

  def keep_private_comments_private
    if private_in_database && !private?
      errors.add(:base, I18n.t('private_comment_cannot_be_public'))
    end
  end

  def link
    (entry ? "#{entry.link}#comment-#{id}" : '#')
  end
end
