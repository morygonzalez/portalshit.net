# ワーカーの数
worker_processes 2 # default is 2

LOKKA_ROOT = File.expand_path('../', File.dirname(__FILE__))

# ソケット
listen File.expand_path('tmp/sockets/unicorn.sock', LOKKA_ROOT)

# pid
pid File.expand_path('tmp/pids/unicorn.pid', LOKKA_ROOT)

# ログ
stderr_path File.expand_path('log/unicorn.log', LOKKA_ROOT)
stdout_path File.expand_path('log/unicorn.log', LOKKA_ROOT)

# ダウンタイムなくす
preload_app true

before_fork do |server, worker|
  old_pid = "#{ server.config[:pid] }.oldbin"
  unless old_pid == server.pid
    begin
      # SIGTTOU だと worker_processes が多いときおかしい気がする
      Process.kill :QUIT, File.read(old_pid).to_i
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end
