# frozen_string_literal: true

module Lokka
  module NgWords
    def self.registered(app)
      app.before do
        path = request.env['PATH_INFO']
        if params['comment'] && %r{^/admin/comments} !~ path
          params['comment']['status'] = if logged_in?
                                          Comment::APPROVED # approved
                                        elsif spam?
                                          Comment::SPAM # spam
                                        else
                                          Comment::MODERATED # moderated
                                        end
        end
      end

      app.get '/admin/plugins/ng_words' do
        login_required
        @ng_words = ng_words
        haml :"#{ng_words_view}index", layout: :"admin/layout"
      end

      app.put '/admin/plugins/ng_words' do
        login_required
        Option.ng_words = ng_words_params
        if Option.ng_words
          flash[:notice] = t('ng_words.updated')
          redirect to('/admin/plugins/ng_words')
        else
          flash[:notice] = t('ng_words.db_error')
        end
        haml :"#{ng_words_view}index", layout: :"admin/layout"
      end
    end
  end

  module Helpers
    def ng_words_view
      'plugin/lokka-ng_words/views/'
    end

    def spam?
      ng_words&.split(',')&.flatten&.any? {|word| params[:comment][:body] =~ /#{word.strip}/i }
    end

    def ng_words
      Option.ng_words&.split(',')&.map(&:strip)
    end

    def ng_words_params
      params[:ng_words].values.delete_if {|item| item.blank? }.join(', ')
    end
  end
end
