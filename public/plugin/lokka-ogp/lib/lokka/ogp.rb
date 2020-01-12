# frozen_string_literal: true

require 'fastimage'
require 'open_graph_reader'
require_relative 'ogp/generator'
require_relative 'ogp/fetcher'
require_relative 'ogp/helpers'

module Lokka
  module OGP
    using RefineHash

    def self.registered(app)
      app.helpers OGP::Helpers

      app.before do
        content_for :header do
          ogp.merge(twitter_card).to_meta_tags
        end
      end

      app.get '/ogp' do
        url = params['url']
        fetcher = Lokka::OGP::Fetcher::EachFetcher.new(url)
        if fetcher.fetch
          element = fetcher.element
          path = "#{Lokka.root}/tmp/ogp/#{element.uname}"
          html = File.open(path).read
          cache_control :public, :must_revalidate, max_age: 12.hours
          html
        end
      end
    end
  end
end

class Entry
  alias _original_body body
  def ogp_fetched_body
    @fetched ||= Lokka::OGP::Fetcher.new(_original_body).replace
  end
  alias body ogp_fetched_body

  alias _original_short_body short_body
  def ogp_fetched_short_body
    @short_fetched ||= Lokka::OGP::Fetcher.new(_original_short_body).replace
  end
  alias short_body ogp_fetched_short_body
end

Faraday.default_connection = Faraday.new(headers: { user_agent: 'OpenGraphReader' })
