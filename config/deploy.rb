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
  'config/newrelic.yml',
  'db/database.yml',
  '.env',
  'public/access-ranking.txt',
  'public/referer-ranking.txt',
  'public/cache-hit-rate.txt',
  'public/spam-block-rate.txt',
  'public/access-ranking-today.txt',
  'public/referer-ranking-today.txt',
  'public/cache-hit-rate-today.txt',
  'public/spam-block-rate-today.txt',
  'public/access-ranking-yesterday.txt',
  'public/referer-ranking-yesterday.txt',
  'public/cache-hit-rate-yesterday.txt',
  'public/spam-block-rate-yesterday.txt',
  'public/ads.txt'

# Default value for linked_dirs is []
append :linked_dirs,
  'log',
  'tmp/pids',
  'tmp/sockets',
  'tmp/amazon',
  'tmp/ogp',
  'vendor/bundle'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :bundle_without, %w{test postgresql sqlite batch}.join(' ')

set :puma_conf, '/var/www/app/portalshit/config/puma.rb'

namespace :deploy do
  desc 'Build JavaScript'
  task :build_js do
    on roles(:web) do
      within release_path do
        latest_release = capture(:ls, '-xr', releases_path).split[1]
        latest_release_path = releases_path.join(latest_release)
        assets_combinations = [
          {
            path: 'public/plugin/lokka-archives/assets',
            command: %i[rake 'theme:portalshit:build_js']
          },
          {
            path: 'public/theme/portalshit/scripts',
            command: %i[rake 'plugin:archives:build_js']
          }
        ]
        assets_combinations.each do |hash|
          path, command = hash[:path], hash[:command]
          info "Start building #{path}"
          latest_assets_dir = latest_release_path.join(path)
          release_assets_dir = release_path.join(path)
          latest_manifest = latest_assets_dir.join('manifest.json')
          release_manifest = release_assets_dir.join('manifest.json')
          # check if directory exist
          if [release_manifest, latest_manifest].map {|d| test "[ -e #{d} ]"}.uniq == [false]
            info "Skip because both directories/files do not exist #{path}"
            next
          end
          # check manifest diff
          if test(:diff, '-Nqr', release_manifest, latest_manifest)
            begin
              execute(:cp, '-r', latest_assets_dir, File.dirname(release_assets_dir))
              execute(:ls, release_assets_dir.join('*.js'))
              info "Copying assets dir because the manifest file is not changed #{path}"
              next
            rescue SSHKit::Command::Failed
              info "The manifest file is not changed but copying assets failed. Falling back to building JavaScripts #{path}"
            end
          end
          execute(*command)
        end
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
