#-*- coding: utf-8 -*-
require "bundler/capistrano"
require "capistrano_colors"

set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "portalshit"
set :repository,  "https://github.com/morygonzalez/lokka.git"
set :branch,      "portalshit"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :user,     "morygonzalez"
set :use_sudo, false

# role :web, "54.248.96.173"                          # Your HTTP server, Apache/etc
# role :app, "54.248.96.173"                          # This may be the same as your `Web` server
# role :db,  "your primary db-server here", :primary => true # This is where Rails migrations will run
# role :db,  "your slave db-server here"

set :deploy_to, "/home/morygonzalez/sites/deploys/#{application}"
set :ruby_path, "/home/morygonzalez/.rbenv/shims"
set :normalize_asset_timestamps, false

set :bundle_without, [:development, :test, :postgresql, :sqlite]

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
    set :db_user, -> { Capistrano::CLI.ui.ask('MySQL User: ') }
    set :db_password, -> { Capistrano::CLI.password_prompt('MySQL Password: ') }
    set :db_path, "mysql://#{db_user}:#{db_password}@#{db_host}/portalshit"
    run <<-EOC
      cd #{current_path};
      env RACK_ENV=#{stage}
      env NEWRELIC_ENABLE=#{stage.to_s == 'production' ? true : false}
      env DATABASE_URL=#{db_path}
      bundle exec unicorn -c #{current_path}/config/unicorn.rb -D -E production
    EOC
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "kill -KILL `cat #{current_path}/tmp/pids/unicorn-lokka.pid`"
  end

  task :restart, :role => :app, :except => { :no_release => true } do
    run "kill -USR2 `cat #{current_path}/tmp/pids/unicorn-lokka.pid`"
  end

  task :migrate, :role => :app, :except => { :no_release => true } do
    run "env DATABASE_URL=#{db_path} RACK_ENV=production #{ruby_path}/bundle exec rake db:migrate"
  end

  desc "Do git checkout public dir to work app correctly"
  task :git_checkout_public, :role => :app, :except => { :no_release => true } do
    run "cd #{current_path}; git checkout public"
  end

  desc "Creates sockets symlink"
  task :socket_symlink, :role => :app, :except => { :no_release => true } do
    run "ln -sfn #{shared_path}/sockets #{current_path}/tmp/sockets"
  end

  desc "Create amazon product advertisng api cache files"
  task :amazon_symlink, :role => :app, :except => { :no_release => true } do
    run "ln -sfn #{shared_path}/amazon #{current_path}/tmp/amazon"
  end

  before [:"deploy:start", :"deploy:restart"], :"deploy:socket_symlink"
  before [:"deploy:start", :"deploy:restart"], :"deploy:amazon_symlink"
  after  :"deploy:create_symlink", :"deploy:git_checkout_public"
  after :deploy, :"deploy:cleanup"
end

