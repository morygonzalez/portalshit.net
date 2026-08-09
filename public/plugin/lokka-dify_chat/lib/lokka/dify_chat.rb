# frozen_string_literal: true

require 'json'
require 'dify/chat_client'

module Lokka
  module DifyChat
    def self.client
      @client ||= Dify::ChatClient.new(
        api_base: ENV.fetch('DIFY_CHAT_API_BASE', 'https://api.dify.ai'),
        api_key: ENV['DIFY_CHAT_API_KEY']
      )
    end

    # lokka-ogp の Element#secure_image は private のため、
    # 同じホットリンク対策ロジックをここに複製する
    def self.secure_image_url(image)
      image_str = image.to_s
      return image_str if image_str.empty?

      exclude_regexp = /(githubusercontent|=\d|token=\w+)/
      if image_str.start_with?('http') && !image_str.match?(exclude_regexp)
        "https://portalshit.net/imageproxy/200/#{image_str}"
      else
        image_str
      end
    end

    def self.registered(app)
      app.post '/api/chat/messages' do
        client = Lokka::DifyChat.client
        halt 503, { error: 'chat is not configured' }.to_json unless client.credentials_present?

        payload = JSON.parse(request.body.read) rescue {}
        query = payload['query'].to_s.strip
        halt 400, { error: 'query is required' }.to_json if query.empty?

        user = payload['user'].to_s
        halt 400, { error: 'user is required' }.to_json if user.empty?

        conversation_id = payload['conversation_id'].to_s
        conversation_id = nil if conversation_id.empty?

        headers 'Content-Type' => 'text/event-stream',
                'Cache-Control' => 'no-cache',
                'X-Accel-Buffering' => 'no'

        stream do |out|
          begin
            client.send_message(query: query, user: user, conversation_id: conversation_id) do |response|
              if response.is_a?(Net::HTTPSuccess)
                response.read_body {|chunk| out << chunk }
              else
                message = { event: 'error', message: "upstream error (#{response.code})" }
                out << "data: #{JSON.dump(message)}\n\n"
              end
            end
          rescue StandardError => e
            out << "data: #{JSON.dump(event: 'error', message: e.message)}\n\n"
          end
        end
      end

      app.post '/api/chat/stop' do
        content_type :json
        client = Lokka::DifyChat.client
        halt 503, { error: 'chat is not configured' }.to_json unless client.credentials_present?

        payload = JSON.parse(request.body.read) rescue {}
        task_id = payload['task_id'].to_s
        user = payload['user'].to_s
        halt 400, { error: 'task_id and user are required' }.to_json if task_id.empty? || user.empty?

        response = client.stop_message!(task_id: task_id, user: user)
        status response.code.to_i
        response.body
      end

      app.get '/api/chat/parameters' do
        content_type :json
        client = Lokka::DifyChat.client
        halt 503, { error: 'chat is not configured' }.to_json unless client.credentials_present?

        response = client.parameters
        status response.code.to_i
        response.body
      end

      app.get '/api/chat/history' do
        content_type :json
        client = Lokka::DifyChat.client
        halt 503, { error: 'chat is not configured' }.to_json unless client.credentials_present?

        conversation_id = params[:conversation_id].to_s
        user = params[:user].to_s
        halt 400, { error: 'conversation_id and user are required' }.to_json if conversation_id.empty? || user.empty?

        response = client.messages(conversation_id: conversation_id, user: user, first_id: params[:first_id])
        status response.code.to_i
        response.body
      end

      app.get '/api/chat/ogp' do
        content_type :json
        url = params[:url].to_s
        halt 400, { error: 'url is required' }.to_json if url.empty?

        begin
          parsed = URI.parse(url)
        rescue URI::InvalidURIError
          halt 400, { error: 'invalid url' }.to_json
        end
        halt 400, { error: 'invalid url' }.to_json unless parsed.is_a?(URI::HTTP)

        begin
          fetcher = Lokka::OGP::Fetcher.new(url)
          fetcher.fetch
          element = fetcher.element

          cache_control :public, max_age: 3600
          {
            url: url,
            title: element.title.to_s,
            description: element.description.to_s,
            image: Lokka::DifyChat.secure_image_url(element.image),
            host: element.host.to_s
          }.to_json
        rescue StandardError => e
          logger.error("[dify_chat] ogp fetch failed: #{e.class}: #{e.message}") if respond_to?(:logger)
          status 502
          { error: 'failed to fetch OGP' }.to_json
        end
      end

      app.get '/api/chat/suggested' do
        content_type :json
        client = Lokka::DifyChat.client
        halt 503, { error: 'chat is not configured' }.to_json unless client.credentials_present?

        message_id = params[:message_id].to_s
        user = params[:user].to_s
        halt 400, { error: 'message_id and user are required' }.to_json if message_id.empty? || user.empty?

        response = client.suggested_questions(message_id: message_id, user: user)
        status response.code.to_i
        response.body
      end
    end
  end
end
