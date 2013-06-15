require 'im-kayac'

module Lokka
  module CommentNotifier
    def self.registered(app)
      app.before do
        path = request.env['PATH_INFO']
        if valid_comment?(params["comment"]) && /^\/admin\/comments/ !~ path
          message =<<-RUBY
#{@site.title}: #{params["comment"]["name"]} has posted a new comment.
#{truncate(escape_html(params["comment"]["body"]))}
          RUBY
          case Option.comment_notify_by
          when 'im.kayac.com'
            begin
              if Option.comment_notify_password.present?
                ImKayac.to(Option.comment_notify_to).password(Option.comment_notify_password).post(message)
              elsif Option.comment_notify_sig.present?
                require 'digest/sha1'
                signature = Digest::SHA1.hexdigest(message + Option.comment_notify_sig)
                ImKayac.to(Option.comment_notify_to).secret(signature).post(message)
              else
                ImKayac.to(Option.comment_notify_to).post(message)
              end
            rescue => e
              STDERR.puts e
            end
          when 'email'
            raise "GomenMadaDekitenai"
          else
          end
        end
      end

      app.get '/admin/plugins/comment_notifier' do
        haml :"plugin/lokka-comment_notifier/views/index", :layout => :"admin/layout"
      end

      app.put '/admin/plugins/comment_notifier' do
        if valid_params? params[:comment_notifier]
          Option.comment_notify_by = params[:comment_notifier][:notify_by]
          Option.comment_notify_to = params[:comment_notifier][:notify_to]
          Option.comment_notify_password = params[:comment_notifier][:password]
          Option.comment_notify_sig = params[:comment_notifier][:sig]
          flash[:notice] = t("comment_notifier.configuration_was_successfully_updated")
          redirect '/admin/plugins/comment_notifier'
        else
          flash[:notice] = t('comment_notifier.invalid_value')
          haml :"plugin/lokka-comment_notifier/views/index", :layout => :"admin/layout"
        end
      end
    end
  end

  module Helpers
    def valid_params?(params)
      return false unless params[:notify_by] =~ /^(?:email|im.kayac.com)$/
      if params[:notify_by] == 'email'
        valid_email = /^[0-9a-zA-Z\.-_\+]+[^.]+?@[a-zA-Z0-9-]+?\.(\w{2,3}){2}/
        return false unless params[:notify_to] =~ valid_email
      end

      true
    end

    def valid_comment?(comment)
      Comment.new(comment).valid?
    end
  end
end
