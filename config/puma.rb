#!/usr/bin/env puma

directory '/home/morygonzalez/sites/deploys/portalshit/current'
rackup "/home/morygonzalez/sites/deploys/portalshit/current/config.ru"
environment 'production'

pidfile "/home/morygonzalez/sites/deploys/portalshit/shared/tmp/pids/puma.pid"
state_path "/home/morygonzalez/sites/deploys/portalshit/shared/tmp/pids/puma.state"
stdout_redirect '/home/morygonzalez/sites/deploys/portalshit/shared/log/puma_access.log', '/home/morygonzalez/sites/deploys/portalshit/shared/log/puma_error.log', true

threads 0,16

bind 'unix:///home/morygonzalez/sites/deploys/portalshit/shared/tmp/sockets/puma.sock'

workers 0

prune_bundler

on_restart do
  puts 'Refreshing Gemfile'
  ENV["BUNDLE_GEMFILE"] = "/home/morygonzalez/sites/deploys/portalshit/current/Gemfile"
end
