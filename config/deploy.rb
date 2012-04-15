#-*- coding: utf-8 -*-
require "bundler/capistrano"
require "capistrano_colors"

set :application, "portalshit"
set :repository,  "https://github.com/morygonzalez/lokka.git"
set :branch, "portalshit"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :user, "morygonzalez"
set :use_sudo, false

role :web, "49.212.0.51"                          # Your HTTP server, Apache/etc
role :app, "49.212.0.51"                          # This may be the same as your `Web` server
# role :db,  "your primary db-server here", :primary => true # This is where Rails migrations will run
# role :db,  "your slave db-server here"

set :deploy_to, "/home/morygonzalez/sites/deploys/#{application}"
set :ruby_path, "/home/morygonzalez/.rbenv/shims"
set :db_path, "sqlite3://#{deploy_to}/shared/db/production.sqlite3"
set :normalize_asset_timestamps, false

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path}; env LOKKA_ROOT=#{current_path} env DATABASE_URL=#{db_path} bundle exec unicorn -c #{current_path}/config/unicorn.rb -D -E production"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "kill -KILL `cat #{current_path}/pids/unicorn-lokka.pid`"
  end

  task :restart, :role => :app, :except => { :no_release => true } do
    run "kill -USR2 `cat #{current_path}/pids/unicorn-lokka.pid`"
  end

  task :migrate, :role => :app, :except => { :no_release => true } do
    run "env DATABASE_URL=#{db_path} RACK_ENV=production #{ruby_path}/bundle exec rake db:migrate"
  end

  desc "Do git checkout public dir to work app correctly"
  task :git_checkout_public, :role => :app, :except => { :no_release => true } do
    run "git checkout #{current_path}/public"
  end

  desc "Creates sockets symlink"
  task :socket_symlink, :role => :app, :except => { :no_release => true } do
    run "ln -s #{shared_path}/sockets #{current_path}/tmp/sockets" unless File.exists? "#{current_path}/tmp/sockets"
  end

  before "deploy:start", :"deploy:socket_symlink"
  after "deploy:symlink", :"deploy:git_checkout_public"
end
