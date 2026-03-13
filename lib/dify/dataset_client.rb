# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Dify
  class DatasetClient
    attr_reader :api_base, :dataset_id, :dataset_token, :env

    def initialize(api_base:, dataset_id:, dataset_token:, env: ENV)
      @api_base = api_base
      @dataset_id = dataset_id
      @dataset_token = dataset_token
      @env = env
    end

    def credentials_present?
      dataset_id && dataset_token
    end

    def ensure_credentials!
      raise 'ENV[DATASET_ID] not set' unless dataset_id
      raise 'ENV[DATASET_API_KEY] not set' unless dataset_token
    end

    def create_document_by_text!(name:, text:, process_rule: nil)
      response = http_post_json("/v1/datasets/#{dataset_id}/document/create-by-text", {
        name: name,
        text: text,
        indexing_technique: 'high_quality',
        process_rule: process_rule || { mode: 'automatic' }
      })

      body = JSON.parse(response.body) rescue {}
      unless response.is_a?(Net::HTTPSuccess) && body.dig('document', 'id')
        raise "create-by-text failed #{response.code} #{response.body}"
      end

      body.dig('document', 'id')
    end

    def update_document_by_text!(document_id:, name:, text:, process_rule: nil)
      response = http_post_json("/v1/datasets/#{dataset_id}/documents/#{document_id}/update_by_text", {
        name: name,
        text: text,
        process_rule: process_rule || { mode: 'automatic' }
      })

      body = JSON.parse(response.body) rescue {}
      unless response.is_a?(Net::HTTPSuccess) && body.dig('document', 'id')
        raise "update_by_text failed #{response.code} #{response.body}"
      end

      body.dig('document', 'id')
    end

    def update_documents_metadata!(pairs)
      return if pairs.nil? || pairs.empty?

      field_ids = {
        'period' => (env['PERIOD_ID'] || env['METADATA_ID_PERIOD']),
        'count'  => (env['COUNT_ID']  || env['METADATA_ID_COUNT'])
      }.compact

      operation_data = pairs.map do |pair|
        metadata_list = pair.fetch(:metadata).filter_map do |key, value|
          field_id = field_ids[key.to_s]
          unless field_id && !field_id.empty?
            warn "[metadata] skip key=#{key} (field id not configured)"
            next
          end

          { id: field_id, name: key.to_s, value: value }
        end

        { document_id: pair.fetch(:document_id), metadata_list: metadata_list }
      end

      response = http_post_json("/v1/datasets/#{dataset_id}/documents/metadata", { operation_data: operation_data })
      code = response.code.to_i
      raise "metadata update failed #{response.code} #{response.body}" unless code == 202 || code == 200

      response
    end

    def list_all_documents(page_size: 100)
      documents = []
      page = 1

      loop do
        response = http_get("/v1/datasets/#{dataset_id}/documents", { page: page, limit: page_size })
        body = JSON.parse(response.body) rescue {}
        unless response.is_a?(Net::HTTPSuccess) && body['data'].is_a?(Array)
          raise "list documents failed #{response.code} #{response.body}"
        end

        documents.concat(body['data'])
        total = body['total'] || documents.size
        break if documents.size >= total || body['data'].empty?

        page += 1
      end

      documents
    end

    private

    def http_get(path, query = {})
      uri = URI.join(api_base, path)
      uri.query = URI.encode_www_form(query) unless query.empty?

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{dataset_token}"

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end

    def http_post_json(path, body_hash)
      uri = URI.join(api_base, path)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{dataset_token}"
      request['Content-Type']  = 'application/json'
      request.body = JSON.dump(body_hash)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end
  end
end
