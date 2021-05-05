# frozen_string_literal: true

module Lokka
  module CommentDisallow
    def self.registered(app)
      app.get '/admin/plugins/comment_disallow' do
        login_required
        @comment_disallowed_slugs = comment_disallowed_slugs
        haml :"#{comment_disallow_view}index", layout: :"admin/layout"
      end

      app.put '/admin/plugins/comment_disallow' do
        login_required
        Option.comment_disallowed_slugs = comment_disallow_params
        if Option.comment_disallowed_slugs
          flash[:notice] = t('comment_disallow.updated')
          redirect to('/admin/plugins/comment_disallow')
        else
          flash[:notice] = t('comment_disallow.db_error')
        end
        haml :"#{comment_disallow_view}index", layout: :"admin/layout"
      end
    end
  end

  module Helpers
    def comment_disallow_view
      'plugin/lokka-comment_disallow/views/'
    end

    def comment_disallowed_slugs
      Option.comment_disallowed_slugs&.split(',')&.map(&:strip)
    end

    def comment_disallow_params
      params[:comment_disallow].values.delete_if {|item| item.blank? }.join(', ')
    end
  end
end
