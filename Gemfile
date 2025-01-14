# frozen_string_literal: true

source 'https://rubygems.org'
ruby '~> 2.4'

gem 'activerecord', '~> 5.2'
gem 'activerecord-import'
gem 'activesupport', '~> 5.2'
gem 'awesome_print'
gem 'aws-sdk-s3'
gem 'aws-sdk-sesv2'
gem 'backports', require: false
gem 'bcrypt'
gem 'builder'
gem 'bundler'
gem 'coderay'
gem 'coffee-script'
gem 'compass'
gem 'erubis'
gem 'haml'
gem 'i18n'
gem 'json', '~> 2.3'
gem 'kaminari-activerecord'
gem 'kaminari-sinatra'
gem 'kramdown'
gem 'marcel'
gem 'nokogiri'
gem 'padrino-helpers'
gem 'puma'
gem 'puma_worker_killer'
gem 'pry'
gem 'rack'
gem 'rack-flash'
gem 'rake'
gem 'redcarpet'
gem 'RedCloth'
gem 'request_store'
gem 'sass', '< 3.7.5'
gem 'sinatra', '~> 1.4'
gem 'sinatra-cache', git: 'https://github.com/morygonzalez/sinatra-cache'
gem 'sinatra-contrib'
gem 'sinatra-flash'
gem 'slim'
gem 'tilt'
gem 'tux'
gem 'yard-sinatra'
gem 'tantiny'
gem 'natto'

Dir['public/plugin/lokka-*/Gemfile'].each {|path| eval(File.read(path)) }

group :production do
  gem 'newrelic_rpm'
  gem 'rack-ssl-enforcer'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', '3.14.0', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-rbenv-install', require: false
  gem 'capistrano3-puma', require: false
  gem 'haml-lint'
  gem 'rubocop'
  gem 'sshkit', require: false
end

group :development, :test do
  gem 'database_cleaner-active_record'
  gem 'factory_girl', '~> 4.0'
  gem 'rack-test', require: 'rack/test'
  gem 'rspec', '~> 2.99'
  gem 'simplecov', require: false
  gem 'sqlite3', '~> 1.6.0', group: :batch
end

group :mysql do
  gem 'mysql2'
end

group :postgresql do
  gem 'pg'
end
