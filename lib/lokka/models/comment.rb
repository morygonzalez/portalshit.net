# frozen_string_literal: true

class Comment
  include DataMapper::Resource

  MODERATED = 0
  APPROVED  = 1
  SPAM      = 2

  property :id, Serial
  property :entry_id, Integer
  property :status, Integer # 0: moderated, 1 => approved
  property :name, String
  property :email, String, length: (0..40), format: :email_address
  property :homepage, String
  property :body, Text
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :entry

  default_scope(:default).update(order: :created_at.desc)

  validates_presence_of :name
  validates_presence_of :body

  after :save, :send_notification_to_entry_author

  def self.recent(count = 5)
    all(status: APPROVED, limit: count, order: [:created_at.desc])
  end

  def self.moderated
    all(status: MODERATED)
  end

  def self.approved
    all(status: APPROVED)
  end

  def self.spam
    all(status: SPAM)
  end

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

def Comment(id)
  Comment.get(id)
end
