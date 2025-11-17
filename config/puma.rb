# Puma configuration file
# https://github.com/puma/puma/blob/master/examples/config.rb

# Environment
environment ENV.fetch('RACK_ENV', 'development')

# Port
port ENV.fetch('PORT', 5555)

# Workers (for production, use multiple workers)
workers ENV.fetch('PUMA_WORKERS', 2).to_i

# Threads
threads_count = ENV.fetch('PUMA_MAX_THREADS', 5).to_i
threads threads_count, threads_count

# Preload application for faster worker spawn times
preload_app!

# PID file
pidfile ENV.fetch('PIDFILE', 'tmp/pids/server.pid')

# State file
state_path ENV.fetch('STATE_PATH', 'tmp/pids/puma.state')

# Logging (only in development, systemd handles logging in production)
if ENV['RACK_ENV'] == 'development'
  stdout_redirect 'log/puma.stdout.log', 'log/puma.stderr.log', true
end

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Systemd integration - notify systemd when ready
if ENV['NOTIFY_SOCKET']
  require 'sd_notify'

  on_worker_boot do
    SdNotify.ready
  end

  on_restart do
    SdNotify.reloading
  end

  after_worker_boot do
    SdNotify.ready
  end
end

# Worker timeout
worker_timeout ENV.fetch('PUMA_WORKER_TIMEOUT', 60).to_i

# Preload app for copy-on-write memory savings
on_worker_boot do
  # Re-establish database connections
  if defined?(Sequel)
    Sequel::DATABASES.each(&:disconnect)
  end
end

before_fork do
  # Close database connections before forking
  if defined?(Sequel)
    Sequel::DATABASES.each(&:disconnect)
  end
end
