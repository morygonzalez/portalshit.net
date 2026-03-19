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

        if params[:raw]
          return [header, *filtered].join("\n") + "\n"
        end

        # Aggregate to hourly averages
        headers = header.split("\t")
        numeric_indices = (1...headers.length).to_a

        hourly_groups = filtered.group_by { |line| line[0, 13] } # "2026-03-19T14"
        averaged = hourly_groups.map do |hour_prefix, rows|
          columns = rows.map { |r| r.split("\t") }
          avg = numeric_indices.map do |i|
            values = columns.map { |c| c[i].to_f }
            (values.sum / values.size).round(2)
          end
          [hour_prefix + ':00', *avg].join("\t")
        end

        [header, *averaged].join("\n") + "\n"
      end
    end
  end
end
