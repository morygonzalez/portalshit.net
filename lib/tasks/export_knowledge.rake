# frozen_string_literal: true

begin
  require 'dotenv/load' # 任意（.env 読み込み）
rescue LoadError
end

require 'set'
require 'dify/knowledge_exporter'

namespace :knowledge do
  desc 'Upload posts grouped by year (one document per year)'
  task :upload_yearly, [:sleep_secs, :retries, :chunk_size, :chunk_delimiter] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    abort '[upload_yearly] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless exporter.credentials_present?

    exporter.upload_yearly!(
      sleep_secs: args[:sleep_secs],
      retries: args[:retries],
      chunk_size: args[:chunk_size],
      chunk_delimiter: args[:chunk_delimiter]
    )
  end

  # 年次ドキュメントを update_by_text! で置換（無ければ create）
  # 例:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake "knowledge:refresh_yearly[1.2,6]"
  desc 'Refresh yearly documents (update_by_text; fallback to create if not exists)'
  task :refresh_yearly, [:sleep_secs, :retries] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    abort '[refresh_yearly] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless exporter.credentials_present?

    exporter.refresh_yearly!(
      sleep_secs: args[:sleep_secs],
      retries: args[:retries]
    )
  end

  desc 'Repair metadata (re-apply period/count by listing documents)'
  task :repair_year_metadata, [:batch_size] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    abort '[repair_year_metadata] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless exporter.credentials_present?

    exporter.repair_year_metadata!(batch_size: args[:batch_size])
  end

  # 年指定で1件だけ更新（本文置換＋メタ再付与）
  # 使い方:
  #   DATASET_ID=... DATASET_API_KEY=... bundle exec rake "knowledge:update_year[2025,1.2,6]"
  desc '年指定で1件だけドキュメントを更新'
  task :update_year, [:year, :sleep_secs, :retries, :chunk_size, :chunk_delimiter] do |_, args|
    exporter = Dify::KnowledgeExporter.new
    abort '[update_year] require ENV[DATASET_ID], ENV[DATASET_API_KEY]' unless exporter.credentials_present?

    exporter.update_year!(
      year: args[:year],
      sleep_secs: args[:sleep_secs],
      retries: args[:retries],
      chunk_size: args[:chunk_size],
      chunk_delimiter: args[:chunk_delimiter]
    )
  end

  desc 'Export popular entry'
  task :popular do
    exporter = Dify::KnowledgeExporter.new
    puts exporter.popular_entries_report
  end
end
