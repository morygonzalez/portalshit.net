#!/usr/bin/env puma

directory File.expand_path(File.join(File.dirname(__FILE__), '../'))
rackup 'config.ru'

environment ENV['RACK_ENV']

if ENV['RACK_ENV'] == 'production'
  tmp_dir = File.join(get(:directory),'tmp')
  log_dir = File.join(get(:directory), 'log')
  pid_dir = File.join(tmp_dir, 'pids')

  pidfile         File.join(pid_dir, 'puma.pid')
  state_path      File.join(pid_dir, 'puma.state')
  stdout_redirect File.join(log_dir, 'puma_stdout.log'), File.join(log_dir, 'puma_stderr.log'), true
  bind            "unix://#{File.join(tmp_dir, 'sockets', 'puma.sock')}"

  preload_app!

  workers 2
  before_fork do
    require 'puma_worker_killer'

    PumaWorkerKiller.config do |config|
      config.ram           = 300 # mb
      config.frequency     = 5   # seconds
      config.percent_usage = 0.70
      config.enable_rolling_restart
    end
  end

  on_restart do
    puts 'Refreshing Gemfile'
    ENV["BUNDLE_GEMFILE"] = "/home/morygonzalez/sites/deploys/portalshit/current/Gemfile"
  end

else
  stdout_redirect 'log/puma_stdout.log', 'log/puma_stderr.log', true
  workers 0
  prune_bundler
end

threads 0,8
