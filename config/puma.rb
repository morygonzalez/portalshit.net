#!/usr/bin/env puma

directory '/home/morygonzalez/sites/deploys/portalshit/current'
rackup "/home/morygonzalez/sites/deploys/portalshit/current/config.ru"
environment 'production'

pidfile "/home/morygonzalez/sites/deploys/portalshit/shared/tmp/pids/puma.pid"
state_path "/home/morygonzalez/sites/deploys/portalshit/shared/tmp/pids/puma.state"
stdout_redirect '/home/morygonzalez/sites/deploys/portalshit/shared/log/puma_access.log', '/home/morygonzalez/sites/deploys/portalshit/shared/log/puma_error.log', true

threads 0,16

bind 'unix:///home/morygonzalez/sites/deploys/portalshit/shared/tmp/sockets/puma.sock'

workers 2

# prune_bundler

before_fork do
  require 'puma_worker_killer'

  PumaWorkerKiller.config do |config|
    config.ram           = 512 # mb
    config.frequency     = 5   # seconds
    config.percent_usage = 0.80
    config.enable_rolling_restart
  end
end

on_restart do
  puts 'Refreshing Gemfile'
  ENV["BUNDLE_GEMFILE"] = "/home/morygonzalez/sites/deploys/portalshit/current/Gemfile"
end
