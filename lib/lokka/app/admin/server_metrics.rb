# frozen_string_literal: true

module Lokka
  class App
    namespace '/admin' do
      get '/server-metrics/:filename' do
        filename = params[:filename]
        halt 400 unless filename =~ /\A\d{4}-\d{2}\.tsv\z/

        metrics_dir = File.join(settings.root, 'log', 'server-metrics')
        path = File.join(metrics_dir, filename)
        halt 404 unless File.exist?(path)

        content_type :text
        send_file path
      end
    end
  end
end
