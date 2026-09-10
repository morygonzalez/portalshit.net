# frozen_string_literal: true

class Comment < ActiveRecord::Base
  MODERATED = 0
  APPROVED  = 1
  SPAM      = 2

  belongs_to :entry
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: :parent_id, dependent: :nullify

  validates :name, presence: true
  validates :body, presence: true
  validates :email, presence: true
  validates_length_of :email, in: (1..40)
  validates_length_of :homepage, in: (0..255), if: ->(record) { record.homepage.present? }

  default_scope -> { order('created_at DESC') }

  validate :keep_private_comments_private
  validate :do_not_approve_private_comments
  validate :reply_matches_parent

  scope :publicly_visible, -> { where(status: APPROVED, private: false) }
  scope :private_comments, -> { where(private: true) }
  scope :root_comments, -> { where(parent_id: nil) }
  scope :moderated, -> { where(status: MODERATED) }
  scope :approved,  -> { where(status: APPROVED) }
  scope :spam,      -> { where(status: SPAM) }
  scope :recent,
        ->(count = 5) { publicly_visible.limit(count) }

  def keep_private_comments_private
    if private_in_database && !private?
      errors.add(:base, I18n.t('comment.errors.cannot_be_public'))
    end
  end

  def do_not_approve_private_comments
    if persisted? && private? && status_changed? && status == APPROVED
      errors.add(:base, I18n.t('admin.comment.private.explanation'))
    end
  end

  def reply_matches_parent
    return unless parent

    if parent.entry_id != entry_id
      errors.add(:parent, I18n.t('comment.errors.reply_must_belong_to_same_entry'))
    end
    if parent.private? != private?
      errors.add(:parent, I18n.t('comment.errors.reply_must_match_privacy'))
    end
  end

  def reply?
    parent_id.present?
  end

  def link
    (entry ? "#{entry.link}#comment-#{id}" : '#')
  end
end
