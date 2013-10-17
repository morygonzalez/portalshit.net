puts "*** Deploying to the \033[1;41m  PRODUCTION  \033[0m servers!"

set :domain, '219.94.232.157'
set :db_host, domain
role :web, domain
role :app, domain
role :db,  'localhost', :primary => true

namespace :deploy do
  desc "Create newrelic symlink"
  task :newrelic_symlink, :role => :app, :except => { :no_release => true } do
    run "ln -sfn #{shared_path}/newrelic.yml #{current_path}/config/newrelic.yml"
  end
  before [:"deploy:start", :"deploy:restart"], :"deploy:newrelic_symlink"
end
