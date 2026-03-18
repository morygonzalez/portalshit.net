# config valid only for Capistrano 3.1
# lock '3.13.0'

set :default_env, { 'RUBYOPT' => '--encoding=UTF-8' }

set :application, 'portalshit'
set :repo_url, 'https://github.com/morygonzalez/portalshit.net.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
set :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
# set :branch, 'portalshit'

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'
set :deploy_to, "/var/www/deploys/#{fetch(:application)}"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files,
  'db/database.yml',
  '.env',
  'config/filtered_locations.yml'

# Default value for linked_dirs is []
append :linked_dirs,
  'log',
  'tmp/pids',
  'tmp/sockets',
  'tmp/amazon',
  'tmp/ogp',
  'tmp/index',
  'tmp/popular_entries',
  'vendor/bundle',
  'node_modules',
  'public/log-aggregation',
  'public/og-image'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :bundle_without, %w{test postgresql sqlite batch}.join(' ')

set :puma_conf, '/var/www/app/portalshit/config/puma.rb'
set :user, 'app'
set :puma_systemctl_user, fetch(:user)
set :puma_service_unit_env_vars, ['RACK_ENV=production', 'RUBYOPT=-EUTF-8']
set :puma_access_log, '/var/www/app/portalshit/log/puma_access.log'
set :puma_error_log, '/var/www/app/portalshit/log/puma_error.log'

namespace :deploy do
  desc 'Copy compiled MeCab userdic from Docker image'
  task :compile_userdic do
    on roles(:app) do
      within release_path do
        execute :docker, 'run', '--rm',
          '-v', "#{release_path}/lib/tokenizer:/work",
          'morygonzalez/portalshit:latest',
          'cp', '/app/lib/tokenizer/userdic.dic', '/work/userdic.dic'
      end
    end
  end
  desc 'Run database migrations'
  task :migrate do
    on roles(:app) do
      within release_path do
        execute '/var/www/app/.rbenv/bin/rbenv', 'exec', 'bundle', 'exec', 'rake', 'db:migrate', 'RACK_ENV=production'
      end
    end
  end
  before :restart, :migrate

  before :restart, :compile_userdic

  desc 'Build JavaScript'
  task :build_js do
    on roles(:web) do
      within release_path do
        execute '$HOME/.nodenv/shims/npm', 'install'
        execute '$HOME/.nodenv/shims/npm', 'run', 'build'
      end
    end
  end
  before :restart, :build_js

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end
  desc 'Update crontab'
  task :update_crontab do
    on roles(:app) do
      within release_path do
        execute release_path.join('bin/install_crontab')
      end
    end
  end
  after :publishing, :update_crontab

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
      #
      # within release_path do
      #   execute :sh, 'bin/access_ranking'
      #   execute :sh, 'bin/referer_ranking'
      # end
    end
  end
end
