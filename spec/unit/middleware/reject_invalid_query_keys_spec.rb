# frozen_string_literal: true

require File.expand_path('../../spec_helper', __dir__)

describe Lokka::Middleware::RejectInvalidQueryKeys do
  let(:inner_app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:middleware) { described_class.new(inner_app) }

  def call(query)
    env = Rack::MockRequest.env_for("/?#{query}")
    middleware.call(env)
  end

  context 'with a valid query string' do
    it 'passes through plain keys' do
      status, _headers, body = call('page=2')
      expect(status).to eq 200
      expect(body).to eq ['ok']
    end

    it 'allows multiple valid keys' do
      status, = call('page=2&query=foo&utm_source=bar')
      expect(status).to eq 200
    end

    it 'allows keys starting with underscore' do
      status, = call('_token=abc')
      expect(status).to eq 200
    end

    it 'allows repeated keys' do
      status, = call('tag=a&tag=b')
      expect(status).to eq 200
    end
  end

  context 'with no query string' do
    it 'passes through empty query' do
      status, = middleware.call(Rack::MockRequest.env_for('/'))
      expect(status).to eq 200
    end
  end

  context 'with an invalid query string' do
    it 'rejects keys containing spaces (the reported SQL-injection probe)' do
      status, _headers, body = call("page=3'nvOpzp&%20AND%201=1")
      expect(status).to eq 400
      expect(body).to eq ['Bad Request']
    end

    it 'rejects keys starting with a digit' do
      status, = call('1=2')
      expect(status).to eq 400
    end

    it 'rejects bracketed keys' do
      status, = call('post[title]=foo')
      expect(status).to eq 400
    end

    it 'rejects hyphenated keys' do
      status, = call('utm-source=foo')
      expect(status).to eq 400
    end

    it 'rejects when any one key is invalid even if others are valid' do
      status, = call('page=2&%20bad=1')
      expect(status).to eq 400
    end

    it 'does not call the inner app' do
      called = false
      app = described_class.new(->(_env) { called = true; [200, {}, []] })
      app.call(Rack::MockRequest.env_for('/?%20AND%201=1'))
      expect(called).to eq false
    end
  end
end
