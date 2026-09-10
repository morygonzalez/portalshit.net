# frozen_string_literal: true

module Lokka
  class CommentNotifier
    def initialize(comment)
      @comment = comment
    end

    def notify_commenter
      return if Lokka.test?
      return if @comment.private? || @comment.email.blank?

      client = Aws::SESV2::Client.new(credentials: credentials, region: region)
      client.send_email(email_params)
    end

    def notify_sender_receipt
      return if Lokka.test? || !@comment.persisted? || @comment.email.blank?
      return if @comment.status == Comment::SPAM

      subject = if @comment.private?
                  "メッセージ送信の控え - #{entry.title}"
                else
                  "コメント送信の控え - #{entry.title}"
                end
      subject = "[#{Lokka.env}] #{subject}" unless Lokka.production?
      body = if @comment.private?
               <<~TEXT
                 著者へのメッセージを送信しました。このメッセージはサイトに公開されません。
               TEXT
             else
               <<~TEXT
                 コメントを送信しました。管理者の確認後にサイトへ表示されます。
               TEXT
             end
      body += <<~TEXT

        記事: #{entry.title}
        URL: #{entry_url}

        #{@comment.body}
      TEXT

      client = Aws::SESV2::Client.new(credentials: credentials, region: region)
      client.send_email(
        from_email_address: from,
        reply_to_addresses: reply_to_addresses,
        destination: { to_addresses: [@comment.email] },
        content: {
          simple: {
            subject: { data: subject },
            body: {
              text: { data: body },
              html: { data: Markup.use_engine('redcarpet', body) }
            }
          }
        }
      )
    end

    def notify_author
      return if Lokka.test? || !@comment.private? || !@comment.persisted?
      return if entry&.user&.email.blank?

      client = Aws::SESV2::Client.new(credentials: credentials, region: region)
      subject = "メッセージが届きました - #{entry.title}"
      subject = "[#{Lokka.env}] #{subject}" unless Lokka.production?
      body = <<~TEXT
        著者へのメッセージが届きました。このメッセージはサイトに公開されません。

        記事: #{entry.title}
        投稿者: #{@comment.name}

        #{@comment.body}

        管理画面: https://portalshit.net/admin/comments/#{@comment.id}
      TEXT
      client.send_email(
        from_email_address: from,
        reply_to_addresses: reply_to_addresses,
        destination: { to_addresses: [entry.user.email] },
        content: { simple: { subject: { data: subject }, body: { text: { data: body } } } }
      )
    end

    def notify_reply(parent)
      return if Lokka.test? || !@comment.persisted? || parent.email.blank?

      private_reply = parent.private?
      subject = private_reply ? "メッセージへの返信 - #{entry.title}" : "コメントへの返信 - #{entry.title}"
      subject = "[#{Lokka.env}] #{subject}" unless Lokka.production?
      body = <<~TEXT
        #{parent.name} 様

        #{private_reply ? '著者からメッセージへの返信がありました。' : 'いただいたコメントに返信がありました。'}

        記事: #{entry.title}
        #{"URL: #{entry_url}" unless private_reply}

        #{@comment.body}
      TEXT

      client = Aws::SESV2::Client.new(credentials: credentials, region: region)
      client.send_email(
        from_email_address: from,
        reply_to_addresses: reply_to_addresses,
        destination: { to_addresses: [parent.email] },
        content: { simple: { subject: { data: subject }, body: { text: { data: body } } } }
      )
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

    def reply_to_addresses
      [ENV.fetch('SES_REPLY_TO_ADDRESS', 'morygonzalez@gmail.com')]
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
        reply_to_addresses: reply_to_addresses,
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
