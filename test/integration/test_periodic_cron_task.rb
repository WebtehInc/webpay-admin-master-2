require_relative "integration_helper"

module Gateway
  class PeriodicCronTaskTest < Test

    class TestError < RuntimeError; end

    CRON_ENV_FILE_NAME = "/tmp/webpay-periodic-cron-task-test.cron"
    LOCK_FILE_NAME = "/tmp/webpay-periodic-cron-task-test.lock"

    def setup
      super
      File.delete CRON_ENV_FILE_NAME rescue nil
      File.delete LOCK_FILE_NAME rescue nil
    end

    def test_basic_use
      Timecop.freeze
      @exp_call_time = Time.now
      call_task
      assert_equal @exp_call_time, @last_call_time, 'expected the action to execute on first run'

      Timecop.freeze 10
      call_task
      assert_equal @exp_call_time, @last_call_time, 'expected the action to not execute after 10 seconds'

      Timecop.freeze 5*60
      @exp_call_time = Time.now
      call_task
      assert_equal @exp_call_time, @last_call_time, 'expected the action to execute after 5 minutes + 10 seconds'
    end

    def test_locking
      Thread.abort_on_exception = true
      @test_task_id = nil

      call_task{ @test_task_id = 0 }
      assert_equal 0, @test_task_id, 'expected the test baseline task to succeed'

      Timecop.travel 5*60
      call_task(async: true) { rv = @test_task_id = 1; sleep 2; rv }
      sleep 0.2
      assert_equal 1, @test_task_id, 'expected the first task to succeed'

      call_task{ @test_task_id = 2 }
      assert_equal 1, @test_task_id, 'expected the 2nd task to fail and the first task to succeed'
    end

    def test_working_times
      @exp_call_time = nil

      Timecop.freeze Time.parse('01:00')
      call_task(working_times: ['10:00-11:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to not be executed outside of proper time'

      Timecop.freeze Time.parse('10:00')
      @exp_call_time = Time.now
      call_task(working_times: ['10:00-11:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to be executed at beginning of proper time'

      Timecop.freeze Time.parse('11:00')
      @exp_call_time = Time.now
      call_task(working_times: ['10:00-11:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to be executed at end of proper time'

      Timecop.freeze Time.parse('11:00')
      @exp_call_time = Time.now
      call_task(working_times: ['11:00', '14:00', '23:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to be executed at proper time'
      Timecop.freeze Time.parse('14:00')
      @exp_call_time = Time.now
      call_task(working_times: ['11:00', '14:00', '23:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to be executed at proper time'
      Timecop.freeze Time.parse('23:00')
      @exp_call_time = Time.now
      call_task(working_times: ['11:00', '14:00', '23:00'])
      assert_equal @exp_call_time, @last_call_time, 'expected the task to be executed at proper time'
    end

    def test_normal_return_values
      Timecop.freeze
      rv1 = (call_task(async: true){1}).value
      assert_equal 1, rv1, 'wrong value returned on async call'
      rv1_2 = (call_task(async: true){'no'}).value
      assert rv1_2.is_a?(PeriodicCronTask::NotScheduled), "strange response on unscheduled async call #{rv1_2.inspect}"

      Timecop.freeze 5*60
      rv2 = call_task{2}
      assert_equal 2, rv2, 'wrong value returned on sync call'
      rv2_2 = call_task{'no'}
      assert rv2_2.is_a?(PeriodicCronTask::NotScheduled), "strange response on unscheduled sync call #{rv2_2.inspect}"
    end

    def test_exception_return_values
      Timecop.freeze
      rve_1 = (call_task(async: true){raise TestError.new("1")}).value
      assert rve_1.is_a?(TestError), "wrong exception class on async, got #{rve_1.class} #{rve_1}"
      assert_equal "1", rve_1.message, "wrong message on exception on async call, got #{rve_1.class} #{rve_1.inspect}"

      Timecop.freeze 5*60
      rve_2 = call_task{raise TestError.new("2")}
      assert rve_2.is_a?(TestError), "wrong exception class on async, got #{rve_2} #{rve_2}"
      assert_equal "2", rve_2.message, "wrong message on exception on async call, got #{rve_2.class} #{rve_2.inspect}"
    end


    private

    def call_task options = {}
      options = {every: 5*60, file_name: CRON_ENV_FILE_NAME, lock_file_name: LOCK_FILE_NAME}.merge(options)
      async = options.delete(:async)
      proc = lambda do |env|
        @last_call_time = Time.now
        @last_env = env
        yield if block_given?
      end

      # puts "TIME: " + Time.now.to_s
      if async
        PeriodicCronTask.async_call(:wii, options, &proc)
      else
        PeriodicCronTask.call(:wii, options, &proc)
      end
    end

  end
end
