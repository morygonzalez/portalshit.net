source 'https://rubygems.org'

gem 'bundler'
gem 'rack'
gem 'rack-flash', '~> 0.1.2'
gem 'sinatra-flash', '~> 0.3.0'
gem 'i18n', '~> 0.6.0'
gem 'sinatra', '~> 1.4.2'
gem 'sinatra-contrib', '~> 1.4.0'
gem 'dm-core',          '~> 1.2.1'
gem 'dm-migrations',    '~> 1.2.0'
gem 'dm-timestamps',    '~> 1.2.0'
gem 'dm-validations',   '~> 1.2.0'
gem 'dm-types',         '~> 1.2.2'
gem 'dm-is-tree',       '~> 1.2.0'
gem 'dm-tags',          '~> 1.2.0'
gem 'dm-is-searchable', '~> 1.2.0'
gem 'dm-pager',         :git => 'git://github.com/yayugu/dm-pagination.git'
gem 'dm-aggregates',    '~> 1.2.0'
gem 'data_objects',     '0.10.17'
gem 'request_store'
gem 'builder', '3.0.0'
gem 'haml', '~> 4.0.4'
gem 'sass', '~> 3.2.12'
gem 'tilt', '~> 1.4.1'
gem 'compass', "~> 0.12.2"
gem 'slim', '~> 3.0.7'
gem 'rake'
gem 'erubis', '~> 2.6.6'
gem 'activesupport', '~> 3.2.22'
gem 'nokogiri'
gem 'tux'
gem 'padrino-helpers', '~> 0.11.4'
gem 'coderay', '1.0.5'
gem 'kramdown'
gem 'RedCloth', '4.2.9'
gem 'wikicloth', '0.7.1'
gem 'redcarpet'
gem 'yard-sinatra', '1.0.0'
gem 'backports', '2.3.0'
gem 'unicorn'
gem 'pry'
gem 'newrelic_rpm'
gem 'sinatra-cache', git: 'git://github.com/morygonzalez/sinatra-cache.git'
gem 'coffee-script'

Dir["public/plugin/lokka-*/Gemfile"].each {|path| eval(open(path) {|f| f.read }) }

group :production do
  gem 'rack-ssl-enforcer'
end

group :development do
  gem 'awesome_print'
  gem 'capistrano', require: false
  gem 'capistrano-rbenv', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rbenv-install', require: false
  gem 'sshkit', require: false
  gem 'rbtrace'
  gem 'better_errors'
  gem 'binding_of_caller'
end

group :development, :test do
  gem 'tapp', '1.3.0'
end

group :development do
  gem 'dm-sqlite-adapter', '1.2.0'
end

group :test do
  gem 'dm-transactions', '~> 1.2.0'
  gem 'rack-test', '0.6.1', require: 'rack/test'
  gem 'rspec', '2.14.1'
  gem 'simplecov', require: false
  gem 'factory_girl', '2.6.1'
  gem 'database_cleaner', '0.7.1'
end

group :mysql do
  gem 'dm-mysql-adapter', '1.2.0'
end

group :postgresql do
  gem 'dm-postgres-adapter', '1.2.0'
end
