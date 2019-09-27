# config valid only for Capistrano 3.1
lock '3.10.1'

set :default_shell, '/bin/bash -l'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} rbenv exec"
set :default_env, { 'RUBYOPT' => '--encoding=UTF-8' }

set :application, 'portalshit'
set :repo_url, 'https://github.com/morygonzalez/portalshit.net.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
set :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
# set :branch, 'portalshit'

# Default deploy_to directory is /var/www/my_app
# set :deploy_to, '/var/www/my_app'
set :deploy_to, "/home/morygonzalez/sites/deploys/#{fetch(:application)}"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}
set :linked_files, %w{config/newrelic.yml database.yml .env public/access-ranking.txt public/referer-ranking.txt public/ads.txt}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
set :linked_dirs, %w{log tmp/pids tmp/sockets tmp/amazon tmp/ogp vendor/bundle}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :puma_conf, File.join(current_path, 'config', 'puma.rb')

set :bundle_without, %w{development test postgresql sqlite batch}.join(' ')

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

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
