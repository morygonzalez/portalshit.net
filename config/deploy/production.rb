puts "*** Deploying to the \033[1;41m  PRODUCTION  \033[0m servers!"

set :domain, '54.248.96.173'
set :db_host, '219.94.232.157'
role :web, domain
role :app, domain
role :db,  domain, :primary => true
