# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Dify
  class ChatClient
    attr_reader :api_base, :api_key

    def initialize(api_base:, api_key:)
      @api_base = api_base
      @api_key = api_key
    end

    def credentials_present?
      !api_key.to_s.empty?
    end

    # Streams a chat message from Dify. Yields the Net::HTTPResponse so the
    # caller can check the status and read the SSE body chunk by chunk
    # without buffering the whole response in memory.
    def send_message(query:, user:, conversation_id: nil, inputs: {}, &block)
      uri = URI.join(api_base, '/v1/chat-messages')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'text/event-stream'
      request.body = JSON.dump({
        inputs: inputs,
        query: query,
        response_mode: 'streaming',
        conversation_id: conversation_id,
        user: user
      }.compact)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 120) do |http|
        http.request(request, &block)
      end
    end

    def stop_message!(task_id:, user:)
      http_post_json("/v1/chat-messages/#{task_id}/stop", { user: user })
    end

    def parameters
      http_get('/v1/parameters')
    end

    def messages(conversation_id:, user:, first_id: nil, limit: 20)
      query = { conversation_id: conversation_id, user: user, limit: limit }
      query[:first_id] = first_id if first_id
      http_get('/v1/messages', query)
    end

    def suggested_questions(message_id:, user:)
      http_get("/v1/messages/#{message_id}/suggested", { user: user })
    end

    private

    def http_get(path, query = {})
      uri = URI.join(api_base, path)
      uri.query = URI.encode_www_form(query) unless query.empty?

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{api_key}"

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end

    def http_post_json(path, body_hash)
      uri = URI.join(api_base, path)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = JSON.dump(body_hash)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end
  end
end
