# frozen_string_literal: true

module Lokka
  module Before
    def self.registered(app)
      app.before do
        @site = RequestStore[:site] ||= Site.first
        @title = @site.title

        locales = Lokka.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])
        locales.map! do |locale|
          locale.match?(/-/) ? locale.split('-').first.to_sym : locale.to_sym
        end

        if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
          I18n.locale = params[:locale].to_sym
          session[:locale] = params[:locale].to_sym
          redirect request.referrer
        elsif session[:locale]
          I18n.locale = session[:locale]
        elsif locales.present?
          I18n.locale = (locales & I18n.available_locales).first || I18n.default_locale
        end

        theme = request.cookies['theme']
        if params[:theme]
          theme = params[:theme]
          response.set_cookie('theme', params[:theme])
        end

        @theme = RequestStore[:theme] ||= Theme.new(
          settings.theme,
          request.script_name,
          theme != 'pc' && request.user_agent =~ /iPhone|Android/
        )

        @theme_types ||= []
        ::I18n.load_path += Dir["#{@theme.i18n_dir}/*.yml"] if @theme.exist_i18n?
      end

      app.before %r{(?!^/admin/login$)^/admin/.*$} do
        login_required
      end
    end
  end
end
