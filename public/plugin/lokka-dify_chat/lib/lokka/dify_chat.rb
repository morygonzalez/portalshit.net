# frozen_string_literal: true

require 'json'
require 'dify/chat_client'

module Lokka
  module DifyChat
    class StreamTimeout < StandardError; end

    # SSE は応答が終わるまで Puma のスレッドを 1 本占有し続ける。Dify は 10 秒ごとに
    # ping イベントを送ってくるので ChatClient の read_timeout（1 回の read に対する
    # 上限）は事実上発火しない。ストリーム全体の経過時間で打ち切る必要がある。
    STREAM_TIMEOUT_SECONDS = Integer(ENV.fetch('DIFY_CHAT_STREAM_TIMEOUT', '90'))

    # 同時ストリーム数の上限。Puma は workers 1 × threads 8 なので、チャットが
    # 全スレッドを占有して記事ページが 504 になるのを防ぐため半分を上限にする。
    # nginx 側の limit_conn は IP ごとなので総量を抑えられない。TCP で Puma を
    # 直接叩かれた場合も含め、確実に効く上限はここだけ。
    MAX_CONCURRENT_STREAMS = Integer(ENV.fetch('DIFY_CHAT_MAX_CONCURRENT_STREAMS', '4'))

    def self.client
      @client ||= Dify::ChatClient.new(
        api_base: ENV.fetch('DIFY_CHAT_API_BASE', 'https://api.dify.ai'),
        api_key: ENV['DIFY_CHAT_API_KEY']
      )
    end

    def self.stream_mutex
      @stream_mutex ||= Mutex.new
    end

    # 空きがあればカウンタを増やして true を返す。上限に達していれば false。
    # Sinatra の stream ブロックはルートブロックを抜けた後（body.each の内側）で
    # 実行されるため、取得はルート内、解放は stream ブロックの ensure で行う。
    def self.acquire_stream_slot
      stream_mutex.synchronize do
        @stream_count ||= 0
        return false if @stream_count >= MAX_CONCURRENT_STREAMS

        @stream_count += 1
        true
      end
    end

    def self.release_stream_slot
      stream_mutex.synchronize do
        @stream_count = [(@stream_count || 1) - 1, 0].max
      end
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

    # チャット API はサイト上のウィジェットからしか呼ばれない。Origin か
    # Referer が自サイトのものでなければ拒否することで、curl などでの直叩きを
    # 落とす。Dify のクレジットを第三者に消費されるのと、/api/chat/ogp を
    # 踏み台にされるのを防ぐのが目的。
    #
    # ブラウザの fetch() は同一オリジンの POST に Origin を、GET に Referer を
    # 付ける。どちらも無い場合は通さない。
    def self.same_site_request?(request)
      source = request.env['HTTP_ORIGIN'].presence || request.referer.presence
      return false if source.blank?

      host = URI.parse(source.to_s).host.to_s.downcase
      return false if host.empty?

      allowed_hosts(request).include?(host)
    rescue URI::Error
      false
    end

    # LocalEntry.self_hosts は RequestStore 経由でリクエストホストを含むが、
    # プラグインの before フィルタの実行順に依存したくないので、ここでも
    # request.host を明示的に足しておく（開発環境の localhost 対策）。
    def self.allowed_hosts(request)
      hosts = Lokka::OGP::LocalEntry.self_hosts
      hosts + [request.host.to_s.downcase]
    end

    def self.registered(app)
      app.before '/api/chat/*' do
        unless Lokka::DifyChat.same_site_request?(request)
          content_type :json
          halt 403, { error: 'forbidden' }.to_json
        end
      end

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

        unless Lokka::DifyChat.acquire_stream_slot
          halt 429, { error: 'too many concurrent chat streams' }.to_json
        end

        headers 'Content-Type' => 'text/event-stream',
                'Cache-Control' => 'no-cache',
                'X-Accel-Buffering' => 'no'

        stream do |out|
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          begin
            client.send_message(query: query, user: user, conversation_id: conversation_id) do |response|
              if response.is_a?(Net::HTTPSuccess)
                response.read_body do |chunk|
                  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
                  if elapsed > Lokka::DifyChat::STREAM_TIMEOUT_SECONDS
                    raise Lokka::DifyChat::StreamTimeout,
                          "stream exceeded #{Lokka::DifyChat::STREAM_TIMEOUT_SECONDS}s"
                  end

                  out << chunk
                end
              else
                message = { event: 'error', message: "upstream error (#{response.code})" }
                out << "data: #{JSON.dump(message)}\n\n"
              end
            end
          rescue StandardError => e
            out << "data: #{JSON.dump(event: 'error', message: e.message)}\n\n"
          ensure
            Lokka::DifyChat.release_stream_slot
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
          # 自サイトの記事は Puma のスレッドを自己リクエストで塞がないよう、
          # HTTP を一切発行せず DB から直接カード情報を組み立てる。チャットが
          # 自サイトの記事を引用するたびに自分自身へ GET しに行っていたのが
          # 過去の 504 の原因。
          if Lokka::OGP::LocalEntry.self_host?(url)
            local = Lokka::OGP::LocalEntry.find_entry(url)&.then {|entry| Lokka::OGP::LocalEntry.new(entry, url) }
            halt 404, { error: 'entry not found' }.to_json if local.nil?

            cache_control :public, max_age: 2_592_000
            {
              url: url,
              title: local.title,
              description: local.description,
              image: local.image_url,
              host: local.host
            }.to_json
          else
            fetcher = Lokka::OGP::Fetcher.new(url)
            # lokka-ogp が保存済みのカード HTML を読むだけ。existing_html は
            # キャッシュが無くても取得しに行かないので、任意の URL を渡して
            # サーバーに外部サイトを叩かせる踏み台にはできない。新規取得は
            # 記事本文のレンダリング時だけに閉じている。
            #
            # チャットが引用するリンクは記事本文由来なのでレンダリング時に
            # キャッシュ済み。未キャッシュなら 404 を返し、ウィジェット側は
            # 素のリンク表示にフォールバックする。
            html = fetcher.existing_html
            halt 404, { error: 'card not available' }.to_json if html.blank?

            doc = Nokogiri::HTML.fragment(html)
            card = doc.at_css('.ogp')

            title = card&.at_css('.ogp-summary h3')&.text
            description = card&.at_css('.ogp-summary .description')&.text
            image = card&.at_css('.ogp-image img')&.[]('src')
            host = card&.at_css('.ogp-summary .host')&.text

            cache_control :public, max_age: 2_592_000
            {
              url: url,
              title: title.to_s,
              description: description.to_s,
              image: image.to_s,
              host: host.presence || parsed.host.to_s
            }.to_json
          end
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
