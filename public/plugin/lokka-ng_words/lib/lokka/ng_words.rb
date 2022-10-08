# frozen_string_literal: true
require 'cld'

module Lokka
  module NgWords
    def self.registered(app)
      app.before do
        path = request.env['PATH_INFO']
        if params['comment'] && %r{^/admin/comments} !~ path
          params['comment']['status'] = if logged_in?
                                          Comment::APPROVED # approved
                                        elsif is_it_spam?
                                          Comment::SPAM # spam
                                        else
                                          Comment::MODERATED # moderated
                                        end
        end
      end

      app.get '/admin/plugins/ng_words' do
        login_required
        @ng_words = ng_words
        @ok_languages = ok_languages
        haml :"#{ng_words_view}index", layout: :"admin/layout"
      end

      app.put '/admin/plugins/ng_words' do
        login_required
        Option.ng_words = ng_words_params
        Option.ok_languages = ok_languages_params
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

    def is_it_spam?
      include_ng_words? || other_than_ok_language?
    end

    def include_ng_words?
      ng_words_array = ng_words&.split(',')&.flatten
      ng_words_array&.any? {|word| comment_body =~ /#{word.strip}/i }
    end

    def other_than_ok_language?
      detection = CLD.detect_language(comment_body)
      ok_languages.exclude?(detection[:code])
    end

    def comment_body
      @comment_body ||= params[:comment][:body]
    end

    def ng_words
      Option.ng_words&.split(',')&.map(&:strip) || []
    end

    def ok_languages
      Option.ok_languages&.split(',')&.map(&:strip) || []
    end

    def ng_words_params
      params[:ng_words].values.delete_if {|item| item.blank? }.join(', ')
    end

    def ok_languages_params
      params[:ok_languages].values.delete_if {|item| item.blank? }.join(', ')
    end
  end
end
