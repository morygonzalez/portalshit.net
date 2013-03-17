puts "*** Deploying to the \033[1;42m  STAGING  \033[0m server!"

set :domain, '219.94.232.157'
set :db_host, '54.248.96.173'
role :web, domain
role :app, domain
role :db,  "54.248.96.173"
