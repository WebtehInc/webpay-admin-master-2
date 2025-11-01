class PeriodicCronTask
  require 'yaml'
  require 'filelock'
  require 'concurrent'

  class NotScheduled < Struct.new(:message); end

  attr_reader :cron_task_state

  def self.call *args, &block
    new.call *args, &block
  end

  def call(task, options = {}, &block)
    FileUtils.mkdir_p "./tmp/#{WP_ENV}/"
    options[:task] = task
    options[:every]     ||= 5*60
    options[:file_name] ||= "./tmp/#{WP_ENV}/cron_task_state_for_#{task}.yml"
    options[:lock_file_name] ||= "./tmp/#{WP_ENV}/lock_for_#{task}.yml"
    options[:working_times] ||= ["00:00-24:00"]

    read_cron_task_state_and_validate options

    if options[:async]
      rv = Concurrent::Future.execute do
        begin
          run(options, &block)
        rescue Exception => e
          log e
        end
      end
    else
      rv = run(options, &block)
    end

    return rv
  rescue Exception => e # never break
    log e
    return e
  end

  def self.async_call task, options = {}, &block
    PeriodicCronTask.call(task, options.merge(async: true), &block)
  end


  private

  def run options
    rv = nil

    Filelock options[:lock_file_name], timeout: 0 do
      rv = read_cron_task_state_and_validate options
      break rv if rv

      cron_task_state[:this_run_time] = Time.now
      cron_task_state[:time_frame]    = (cron_task_state[:last_run_time]...cron_task_state[:this_run_time])

      rv = yield cron_task_state

      cron_task_state[:last_run_time] = cron_task_state[:this_run_time]
      File.open(options[:file_name], 'w') { |f| YAML.dump(cron_task_state, f) }
    end

    rv
  rescue Exception => e # never break
    log e
    return e
  end

  def read_cron_task_state_and_validate options
    @cron_task_state = YAML.load_file(options[:file_name]) || {} rescue {}
    cron_task_state[:last_run_time] ||= Time.parse('1977-01-01')

    # do nothing if time is not yet ripe!
    return NotScheduled.new("#{options[:task]}: #{cron_task_state[:last_run_time]} + #{options[:every]} <= #{Time.now}") unless cron_task_state[:last_run_time] + options[:every] <= Time.now

    # do nothing if we're not in the working time
    return NotScheduled.new("#{options[:task]}: #{Time.now} not in working times #{options[:working_times]}") unless in_working_times?(options[:working_times])

    # nil = success
    return nil
  end

  def in_working_times? working_times
    working_times.detect do |working_time|
      start, finish = working_time.split('-')
      finish ||= start
      now = "#{Time.now.hour.to_s.rjust(2, '0')}:#{Time.now.min.to_s.rjust(2, '0')}"

      raise ArgumentError, "start time '#{start}' looks wrong" if start.length != 5
      raise ArgumentError, "finish time '#{finish}' looks wrong" if finish.length != 5

      start <= now && now <= finish
    end
  end

  def log obj
    puts obj.inspect
    if obj.is_a?(Exception)
      puts obj.backtrace.join("\n")
    end
  end

end

