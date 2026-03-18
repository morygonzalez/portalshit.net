# frozen_string_literal: true

module Lokka
  class App
    namespace '/admin' do
      get '/server-metrics/:period' do
        halt 400 unless %w[today yesterday].include?(params[:period])

        jst_today = Time.now.getlocal('+09:00').to_date
        target_date = case params[:period]
                      when 'today'     then jst_today
                      when 'yesterday' then jst_today - 1
                      end

        metrics_dir = File.join(settings.root, 'log', 'server-metrics')
        tsv_path = File.join(metrics_dir, target_date.strftime('%Y-%m') + '.tsv')
        halt 404 unless File.exist?(tsv_path)

        lines = File.readlines(tsv_path, chomp: true)
        header = lines.first
        date_prefix = target_date.strftime('%Y-%m-%d')
        filtered = lines[1..].select { |line| line.start_with?(date_prefix) }

        halt 404 if filtered.empty?

        content_type 'text/tab-separated-values'
        [header, *filtered].join("\n") + "\n"
      end
    end
  end
end
