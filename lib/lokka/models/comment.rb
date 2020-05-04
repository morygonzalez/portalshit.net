# frozen_string_literal: true

class Comment < ActiveRecord::Base
  MODERATED = 0
  APPROVED  = 1
  SPAM      = 2

  belongs_to :entry

  validates :name, presence: true
  validates :body, presence: true
  validates_length_of :email, in: (0..40), if: ->(record) { record.email.present? }

  after_save :send_notification_to_entry_author

  default_scope -> { order('created_at DESC') }

  scope :moderated, -> { where(status: MODERATED) }
  scope :approved,  -> { where(status: APPROVED) }
  scope :spam,      -> { where(status: SPAM) }
  scope :recent,
        ->(count = 5) { where(status: APPROVED).limit(count) }

  def link
    (entry ? "#{entry.link}#comment-#{id}" : '#')
  end

  private

  def send_notification_to_entry_author
    return if Lokka.test?
    return if email == entry.user.email
    credentials = Aws::Credentials.new(Option.aws_access_key_id, Option.aws_secret_access_key)
    region = 'us-east-1'
    client = Aws::SESV2::Client.new(credentials: credentials, region: region)
    client.send_email(notification_params)
  end

  def notification_params
    from = 'portal shit! <info@portalshit.net>'
    to = entry.user.email
    subject_data = %Q(#{name} commented on your entry "#{entry.title}")
    subject_data = "[#{Lokka.env}] #{subject_data}" unless Lokka.production?
    body_data = <<~TEXT
      You have received comment from #{name} on "#{entry.title}", at #{created_at}

      #{body.lines.map {|line| "> #{line}" }.join("\n")}

      See full conversation https://portalshit.net#{link}
    TEXT
    {
      from_email_address: from,
      destination: { to_addresses: [to] },
      content: {
        simple: {
          subject: {
            data: subject_data
          },
          body: {
            text: {
              data: body_data
            },
            html: {
              data: Markup.use_engine('redcarpet', body_data)
            }
          }
        }
      }
    }
  end
end
