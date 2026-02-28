# frozen_string_literal: true

source 'https://rubygems.org'
ruby '~> 3.2'

gem 'activerecord', '~> 6.0'
gem 'activerecord-import'
gem 'activesupport', '~> 6.0'
gem 'awesome_print'
gem 'aws-sdk-s3'
gem 'aws-sdk-sesv2'
gem 'backports', require: false
gem 'bcrypt'
gem 'builder'
gem 'bundler'
gem 'coderay'
gem 'coffee-script'
gem 'sassc'
gem 'haml'
gem 'i18n'
gem 'json', '~> 2.3'
gem 'kaminari-activerecord'
gem 'kaminari-sinatra', github: 'morygonzalez/kaminari-sinatra'
gem 'kramdown'
gem 'marcel'
gem 'nokogiri'
gem 'padrino-helpers', github: 'morygonzalez/padrino-framework'
gem 'puma'
gem 'puma_worker_killer'
gem 'pry'
gem 'rack'
gem 'rackup'
gem 'rack-flash'
gem 'rake'
gem 'redcarpet'
gem 'RedCloth'
gem 'request_store'
gem 'ruby-openai'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-flash'
gem 'sinatra-cache', github: 'morygonzalez/sinatra-cache'
gem 'slim'
gem 'tilt', '~> 2.1.0'
gem 'tux'
gem 'yard-sinatra'
gem 'natto'

Dir['public/plugin/lokka-*/Gemfile'].each {|path| eval(File.read(path)) }

group :production do
  gem 'rack-ssl-enforcer'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', require: false
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
  gem 'rspec', '~> 3.12'
  gem 'rspec-its'
  gem 'simplecov', require: false
  gem 'sqlite3', '~> 1.4', group: :batch
end

group :mysql do
  gem 'mysql2'
end

group :postgresql do
  gem 'pg'
end
