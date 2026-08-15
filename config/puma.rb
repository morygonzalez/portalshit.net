#!/usr/bin/env puma

directory File.expand_path(File.join(File.dirname(__FILE__), '../'))
rackup 'config.ru'

environment ENV['RACK_ENV'] || 'development'

if ENV['RACK_ENV'] == 'production'
  deploy_dir = File.path('/var/www/app/portalshit')
  tmp_dir = File.join(deploy_dir, 'tmp')
  log_dir = File.join(deploy_dir, 'log')
  pid_dir = File.join(tmp_dir, 'pids')

  Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)

  pidfile         File.join(pid_dir, 'puma.pid')
  state_path      File.join(pid_dir, 'puma.state')
  stdout_redirect File.join(log_dir, 'puma_access.log'), File.join(log_dir, 'puma_error.log'), true
  bind            "unix://#{File.join(tmp_dir, 'sockets', 'puma.sock')}"

  preload_app!

  worker_timeout 20

  # メモリ 2GB のサーバーに Lokka を 2 本同居させているため、worker は 1 本に絞る。
  # CPU は常時 99% アイドルなので worker を増やす意味がなく、worker 1 本ぶんの
  # RSS（実測 300〜440MB）を解放するほうが効果が大きい。同時処理数は
  # workers 1 × threads 8 = 8 で、以前の workers 2 × threads 4 と同じ。
  workers 1

  before_fork do
    require 'puma_worker_killer'

    # ram は「クラスタ全体に割り当てる RAM」で、実効しきい値は ram * percent_usage。
    # 768 は worker 2 本時代の値で、workers 1 にした後の実測（master 185MB +
    # worker 424MB = 609MB）は 768 * 0.80 = 614MB の 99% に達していた。worker が
    # 数 MB 育っただけで reaper が発火し、しかも worker が 1 本しかないので回収の
    # たびに数秒の断が出てしまう。
    #
    # マシン 1966MB のうち他の常駐（soba-hozuki 226MB + mysqld 165MB + docker や
    # nginx 等 240MB ≒ 630MB）を引くと portalshit には 900MB 程度まで割ける。
    # しきい値 720MB なら worker は 535MB まで育ってから回収される計算で、通常
    # 運用では発火せず、本当に肥大したときだけ効く。
    PumaWorkerKiller.config do |config|
      config.ram                       = 900 # mb（クラスタ全体。しきい値は 720MB）
      config.frequency                 = 5   # seconds
      config.percent_usage             = 0.80
      config.rolling_restart_frequency = 6 * 3600 # seconds
    end

    # config だけでは reaper は動かない。start を呼ばないと ram / percent_usage の
    # 監視が一切行われず、閾値を超えても worker が回収されない。
    PumaWorkerKiller.start
  end

  on_restart do
    puts 'Refreshing Gemfile'
    ENV["BUNDLE_GEMFILE"] = "/var/www/deploys/portalshit/current/Gemfile"
  end

else
  # production は unix socket のみで待ち受ける。ここで TCP を開くと nginx を迂回して
  # 直接叩けてしまい、nginx 側のレート制限・同時接続制限がバイパスされる。
  port 3000

  stdout_redirect 'log/puma_access.log', 'log/puma_error.log', true
  workers 0
  prune_bundler
end

# SSE（/api/chat/messages）は応答完了までスレッドを 1 本占有する。スレッドは I/O 待ちで
# GVL を解放するので CPU 負荷はほぼ増えない。db/database.yml の pool はこの値以上にすること。
threads 2, 8
