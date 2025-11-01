# puma logging
DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S %z'.freeze
FORMATTED_OUTPUT = ->(input) { "#{Time.now.strftime DATETIME_FORMAT} : |Puma| #{input}"}

def STDOUT.puts(arg)
  super(FORMATTED_OUTPUT.call(arg))
end

def STDERR.puts(arg)
  super(FORMATTED_OUTPUT.call(arg))
end

log_formatter do |str|
  FORMATTED_OUTPUT.call(str)
end

# log requests
log_requests true

stdout_redirect './log/app.log', './log/err.log', true

# preload first to load .env file
preload_app!

# update spa files
require_relative 'spa/updater'
SpaFilesUpdater.update!

# puma files
pidfile "./tmp/puma/puma.pid"
state_path "./tmp/puma/puma.state"
bind "unix://./tmp/puma/puma.sock"

# puma workers and threads
processes_count = Integer(ENV['PUMA_MAX_PROCESSES'] || 5)
workers processes_count
threads_count = Integer(ENV['PUMA_MAX_THREADS'] || 5)
threads threads_count, threads_count

# puma port and env
port        ENV['PORT']   || 5555
environment ENV['WP_ENV'] || 'development'

before_fork do
  # release db connections
  Sequel::Model.db.disconnect

  # enable pumma killer
  if ENV['PUMA_WORKER_KILLER'] == 'true'
    require 'puma_worker_killer'

    # settings
    killer_ram = processes_count * 200 # mb
    killer_frequency = Integer((ENV['PUMA_WORKER_KILLER_INTERVAL_IN_MINUTES'] || 10)) * 60 # seconds
    puts "Puma worker killer enabled: Max RAM for cluster => #{killer_ram} MB, frequency => #{killer_frequency} seconds"

    PumaWorkerKiller.config do |config|
      config.ram           = killer_ram
      config.frequency     = killer_frequency
      config.rolling_restart_frequency = false
    end
    PumaWorkerKiller.start
  end
end

on_worker_boot do
  defined?(Sequel::Model) and Sequel::Model.db.connect(DB.uri)
end
