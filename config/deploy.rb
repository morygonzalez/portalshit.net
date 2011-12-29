require "bundler/capistrano"

set :application, "portal shit!"
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

set :deploy_to, "/home/morygonzalez/sites/www.portalshit.net"
set :ruby_path, "/home/morygonzalez/.rbenv/shims"
set :db_path, "/home/morygonzalez/sites/www.portalshit.net/db/production.sqlite3"

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
  task :start do
    # run "env DATABASE_URL=#{db_path} bundle exec unicorn -c config/unicorn.rb -D -E production"
    run "env DATABASE_URL=#{db_path} #{ruby_path}/bundle exec unicorn -c config/unicorn.rb -D -E production"
  end

  task :stop do
    run "kill `cat tmp/unicorn-lokka.pid`"
  end

  task :restart, :role => :app do
    run "kill -USR2 `cat tmp/unicorn-lokka.pid`"
  end
end

namespace :db do
  task :migrate do
    run "env DATABASE_URL=#{db_path} RACK_ENV=production #{ruby_path}/bundle exec rake db:migrate"
  end
end

namespace :check do
  task :vars do
    run "which ruby; ruby -v"
  end
end
