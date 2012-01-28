# ワーカーの数
worker_processes 2

# ソケット
listen '/tmp/unicorn-lokka.sock'
# listen File.expand_path('tmp/sockets/unicorn-lokka.sock', ENV['LOKKA_ROOT'])

# pid
listen File.expand_path('tmp/pids/unicorn-lokka.pid', ENV['LOKKA_ROOT'])

# ログ
stderr_path 'log/unicorn.log'
stdout_path 'log/unicorn.log'

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
