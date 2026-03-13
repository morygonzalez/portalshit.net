# frozen_string_literal: true

begin
  require 'dotenv/load' # 任意（.env 読み込み）
rescue LoadError
end

require 'dify/knowledge_exporter'

namespace :knowledge do
  # 年次ドキュメントを update_by_text! で置換（無ければ create）
  # 例:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake "knowledge:refresh_yearly[1.2,6]"
  desc 'Refresh yearly documents (update_by_text; fallback to create if not exists)'
  task :refresh_yearly, [:sleep_secs, :retries, :chunk_size, :chunk_delimiter] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    exporter.refresh_yearly!(
      sleep_secs: args[:sleep_secs],
      retries: args[:retries],
      chunk_size: args[:chunk_size],
      chunk_delimiter: args[:chunk_delimiter]
    )
  end

  desc 'Repair metadata (re-apply period/count by listing documents)'
  task :repair_year_metadata, [:batch_size] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    exporter.repair_year_metadata!(batch_size: args[:batch_size])
  end

  # 年指定で1件だけ更新（本文置換＋メタ再付与）
  # 使い方:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake "knowledge:update_year[2025,1.2,6]"
  desc '年指定で1件だけドキュメントを更新'
  task :update_year, [:year, :sleep_secs, :retries, :chunk_size, :chunk_delimiter] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    exporter.update_year!(
      year: args[:year],
      sleep_secs: args[:sleep_secs],
      retries: args[:retries],
      chunk_size: args[:chunk_size],
      chunk_delimiter: args[:chunk_delimiter]
    )
  end

  # メタデータを再適用してドキュメントの無効化を防止
  # 使い方:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake knowledge:touch
  desc 'Touch all documents to prevent auto-archiving'
  task :touch do
    exporter = Dify::KnowledgeExporter.new
    exporter.touch_all!
  end

  # 要約ドライラン: 指定年の記事を要約して結果を表示（Dify にはアップロードしない）
  # 使い方:
  #   OPENAI_API_KEY=... bundle exec rake "knowledge:summarize_preview[2025,3]"
  desc '要約プレビュー（ドライラン）'
  task :summarize_preview, [:year, :limit] do |_, args|
    require 'dify/article_summarizer'

    year  = (args[:year] || Time.now.year).to_s
    limit = (args[:limit] || 5).to_i

    exporter  = Dify::KnowledgeExporter.new
    collector = exporter.article_collector

    rows = collector.collect_for_year(year: year, label: 'summarize_preview')

    rows = rows.first(limit) if limit.positive?

    summarizer = Dify::ArticleSummarizer.new
    summarized = summarizer.summarize_all(rows, label: 'preview')

    summarized.each do |article|
      puts "=" * 60
      puts "Title: #{article[:title]}"
      puts "Date:  #{article[:date]}"
      puts "Original: #{rows.find { |r| r[:id] == article[:id] }&.dig(:content)&.length || '?'} chars"
      puts "Summary:  #{article[:content].length} chars"
      puts "-" * 40
      puts article[:content]
      puts
    end
  end

end
