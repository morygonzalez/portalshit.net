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
            begin
              ImKayac.post(Option.comment_notify_to, message)
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
