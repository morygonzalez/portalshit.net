# frozen_string_literal: true

source 'https://rubygems.org'

gem 'activesupport', '~> 6.0'
gem 'aws-sdk-s3'
gem 'aws-sdk-sesv2'
gem 'backports', '2.3.0'
gem 'builder'
gem 'bundler'
gem 'coderay', '1.0.5'
gem 'coffee-script'
gem 'compass', '1.0.3'
gem 'data_objects',     '0.10.17'
gem 'dm-aggregates',    '~> 1.2.0'
gem 'dm-core',          '~> 1.2.1'
gem 'dm-is-searchable', '~> 1.2.0'
gem 'dm-is-tree',       '~> 1.2.0'
gem 'dm-migrations',    '~> 1.2.0'
gem 'dm-pager',         git: 'https://github.com/lokka/dm-pagination'
gem 'dm-tags',          '~> 1.2.0'
gem 'dm-timestamps',    '~> 1.2.0'
gem 'dm-types',         '~> 1.2.2'
gem 'dm-validations',   '~> 1.2.0'
gem 'dotenv'
gem 'erubis', '~> 2.7.0'
gem 'haml', '~> 5.0'
gem 'i18n', '~> 0.7'
gem 'kramdown'
gem 'mimemagic'
gem 'nokogiri'
gem 'padrino-helpers', '~> 0.14.1.1'
gem 'pry'
gem 'puma'
gem 'puma_worker_killer'
gem 'rack'
gem 'rack-flash', '~> 0.1.2'
gem 'rake', '~> 12.3'
gem 'redcarpet', git: 'https://github.com/vmg/redcarpet.git'
gem 'RedCloth', '4.2.9'
gem 'request_store'
gem 'sass', '>= 3.3.13', '< 3.5'
gem 'sinatra', '~> 1.4.2'
gem 'sinatra-cache', git: 'https://github.com/morygonzalez/sinatra-cache'
gem 'sinatra-contrib', '~> 1.4.0'
gem 'sinatra-flash', '~> 0.3.0'
gem 'slim', '~> 3.0.7'
gem 'tilt', '~> 2.0'
gem 'tux'
gem 'yard-sinatra', '1.0.0'

Dir['public/plugin/lokka-*/Gemfile'].each {|path| eval(File.read(path)) }

group :production do
  gem 'newrelic_rpm'
  gem 'rack-ssl-enforcer'
end

group :development, :test do
  gem 'tapp', '1.3.0'
end

group :development do
  gem 'awesome_print'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', '3.10.1', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-rbenv-install', require: false
  gem 'capistrano3-puma', require: false
  gem 'dm-sqlite-adapter', '1.2.0'
  gem 'haml-lint'
  gem 'rubocop'
  gem 'sshkit', require: false
end

group :test do
  gem 'database_cleaner', '0.7.1'
  gem 'dm-transactions', '~> 1.2.0'
  gem 'factory_girl', '~> 4.0'
  gem 'rack-test', '0.6.1', require: 'rack/test'
  gem 'rspec', '2.14.1'
  gem 'simplecov', require: false
end

group :mysql do
  gem 'dm-mysql-adapter', '1.2.0'
end

group :postgresql do
  gem 'dm-postgres-adapter', '1.2.0'
end

group :batch do
  gem 'natto'
  gem 'sqlite3'
end
