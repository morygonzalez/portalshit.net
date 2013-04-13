puts "*** Deploying to the \033[1;42m  STAGING  \033[0m server!"

set :domain, '219.94.232.157'
set :db_host, domain
role :web, domain
role :app, domain
role :db,  domain
