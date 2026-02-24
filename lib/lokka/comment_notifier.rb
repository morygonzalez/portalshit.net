# frozen_string_literal: true

module Lokka
  class CommentNotifier
    def initialize(comment)
      @comment = comment
    end

    def notify_commenter
      return if Lokka.test?
      return if @comment.email.blank?

      client = Aws::SESV2::Client.new(credentials: credentials, region: region)
      client.send_email(email_params)
    end

    private

    def credentials
      Aws::Credentials.new(Option.aws_access_key_id, Option.aws_secret_access_key)
    end

    def region
      'us-east-1'
    end

    def from
      ENV.fetch('SES_FROM_ADDRESS', 'portal shit! <info@portalshit.net>')
    end

    def entry
      @comment.entry
    end

    def entry_url
      "https://portalshit.net#{entry.link}"
    end

    def subject_data
      subject = "コメントが承認されました - #{entry.title}"
      subject = "[#{Lokka.env}] #{subject}" unless Lokka.production?
      subject
    end

    def body_data
      <<~TEXT
        #{@comment.name} 様

        portalshit.net にいただいたコメントが承認されました。

        記事: #{entry.title}
        URL: #{entry_url}

        ありがとうございました。
      TEXT
    end

    def email_params
      {
        from_email_address: from,
        destination: { to_addresses: [@comment.email] },
        content: {
          simple: {
            subject: { data: subject_data },
            body: {
              text: { data: body_data },
              html: { data: Markup.use_engine('redcarpet', body_data) }
            }
          }
        }
      }
    end
  end
end
