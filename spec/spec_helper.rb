# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
ENV['LOKKA_ENV'] = 'test'

require 'simplecov'

SimpleCov.start do
  skip 'spec/'
  skip 'public/'
  skip 'i18n/'
  skip 'db/'
  skip 'coverage/'
  skip 'tmp/'
  skip 'log/'
end

require File.join(File.dirname(__FILE__), '..', 'init.rb')

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
require 'rspec/its'
require 'factory_bot'
require 'database_cleaner/active_record'
require 'pry'

require 'factories'

set :environment, :test
Lokka::Database.connect
Lokka::Migrator.migrate!

module LokkaTestMethods
  def app
    @app ||= Lokka::App
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.expect_with(:rspec) do |expectations|
    expectations.syntax = %i[expect should]
  end
  config.include Rack::Test::Methods
  config.include LokkaTestMethods
  config.include Lokka::Helpers
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    RequestStore.clear!
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
