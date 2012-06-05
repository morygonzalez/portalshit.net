require 'im-kayac'

module Lokka
  module CommentNotifier
    def self.registered(app)
      app.before do
        path = request.env['PATH_INFO']
        if params["comment"] && /^\/admin\/comments/ !~ path
          message = "#{params["comment"]["name"]}: #{truncate(escape_html(params["comment"]["body"]))}"
          case Option.comment_notify_by
          when 'im.kayac.com'
            if Option.comment_notify_password.present?
              opt = {:password => Option.comment_notify_password}
            elsif Option.comment_notify_sig.present?
              require 'digest/sha1'

              sig = Digest::SHA1.hexdigest(message + Option.comment_notify_sig)
              opt = {:sig => sig}
            else
              opt = nil
            end

            begin
              ImKayac.post(Option.comment_notify_to, message, opt)
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
          flash[:notice] = "Updated."
          redirect '/admin/plugins/comment_notifier'
        else
          flash[:notice] = 'Invalid Value'
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
  end
end
