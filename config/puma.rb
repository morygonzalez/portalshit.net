daemonise true
LOKKA_ROOT = File.expand_path('../', File.dirname(__FILE__))
pidfile File.expand_path('tmp/pids/puma.pid', LOKKA_ROOT)
stdout_redirect File.expand_path('tmp/log/stdout', LOKKA_ROOT), File.expand_path('tmp/log/stderr', LOKKA_ROOT), true
bind "unix://#{File.expand_path('tmp/sockets/puma.sock', LOKKA_ROOT)}"
