# frozen_string_literal: true

module ExceptionNotifier
  class SesNotifier
    def initialize(options)
      @region = options.fetch(:region, 'us-east-1')
      @from = options.fetch(:from, 'portal shit! <info@portalshit.net>')
      @to = options[:to]
    end

    def call(exception, options = {})
      env = options[:env]
      request = env ? Rack::Request.new(env) : nil

      subject = build_subject(exception, request)
      body = build_body(exception, request, env)

      send_email(subject, body)
    rescue => e
      $stderr.puts "ExceptionNotifier::SesNotifier failed: #{e.message}"
    end

    private

    def build_subject(exception, request)
      path = request ? " (#{request.request_method} #{request.path_info})" : ''
      "[portalshit] #{exception.class}#{path}"
    end

    def build_body(exception, request, env)
      sections = []
      sections << "#{exception.class}: #{exception.message}"
      sections << ""

      if request
        sections << "== Request =="
        sections << "URL: #{request.url}"
        sections << "Method: #{request.request_method}"
        sections << "IP: #{request.ip}"
        sections << "User-Agent: #{request.user_agent}"
        sections << "Referer: #{request.referer}" if request.referer
        params = request.params
        sections << "Params: #{params.inspect}" if params && !params.empty?
        sections << ""
      end

      if exception.backtrace
        sections << "== Backtrace =="
        exception.backtrace.each do |line|
          sections << line.sub(%r{/var/www/deploys/portalshit/releases/\d+/}, 'app/')
        end
      end

      sections.join("\n")
    end

    def credentials
      Aws::Credentials.new(Option.aws_access_key_id, Option.aws_secret_access_key)
    end

    def send_email(subject, body)
      client = Aws::SESV2::Client.new(credentials: credentials, region: @region)
      client.send_email(
        from_email_address: @from,
        destination: { to_addresses: Array(@to) },
        content: {
          simple: {
            subject: { data: subject, charset: 'UTF-8' },
            body: { text: { data: body, charset: 'UTF-8' } }
          }
        }
      )
    end
  end
end
