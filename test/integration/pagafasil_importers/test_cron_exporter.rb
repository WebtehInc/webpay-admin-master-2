require_relative "importer_helper"

module PagafasilImporters
  class TestCronExporter < ImporterTest

    # [
    #   ["ae", "Aquaelectra"],                 # Daily every 30 minutes from 5:30am for 12 hours
    #   ["cp", "CUSANPEDRO"],                  # Daily 8am, 11am, 3pm
    #   ["di", "Districo"],                    # Daily 12:15am
    #   ["dp", "Digicel Postpaid"]             # Daily every 15 minutes from 6:30am for 14 hours
    #   ["dt", "DirecTV"],                     # Daily 11am – 2pm – 11pm
    #   ["en", "Entiero Na Kuota"],            # Daily 12:41am
    #   ["ex", "Extura"],                      # Daily 12:40am
    #   ["ff", "FFP"],                         # Daily 12:20am
    #   ["fk", "FKP"],                         # Daily 12:20am
    #   ["fl", "FLOW"],                        # Daily 12:30am
    #   ["ko", "Korpodeko"]                    # Daily midnight
    #   ["om", "OMNI"]                         # Daily 8am, 2pm and 6pm

    #   ["pa", "Pagatinu"]                     # Daily 12:50am
    #   ["pb", "Paga Bo But"],                 # Daily Every hour from 6am for 16 hours
    #   ["se", "Selikor"],                     # Daily every 30 minutes from 5:30am for 12 hours
    #   ["td", "TDS"],                         # Daily 7am and 4pm
    #   ["tr", "TRES"],                        # Hourly, beginning at 8am and ending at 8pm.
    #   ["ut", "UTS"]                          # Daily every 15 minutes from 6:30am for 14 hours
    # ]
    #

    def setup
      super
      @last_time = Time.now - 87464876
      operators = JSON.parse(File.read("./test/fixtures/operators.json"))

      operators.each do |op_attrs|
        Operator.create(op_attrs)
      end
    end

    def test_a_day_on_the_system
      # AQ & SE & UT run all the time

      # ========================= NIGHTLY EXPORTS ==========================
      rv = ce_run_at '00:00'
      assert_result rv, exp_exports(aqse: true,
        ko_export_payments: [:success], ko_export_refunds: [:success])

      rv = ce_run_at '00:10'
      assert_result rv

      # 1-off run by di
      rv = ce_run_at '00:15'
      assert_result rv, exp_exports(
        di_export_payments: [:success], di_export_refunds: [:success])

      rv = ce_run_at '00:17'
      assert_result rv

      # 1-off run by ff, fk
      rv = ce_run_at '00:20'
      assert_result rv,
        ff_export_payments: [:success], ff_export_refunds: [:success],
        fk_export_payments: [:success], fk_export_refunds: [:success]

      # 1-off run by fl
      rv = ce_run_at '00:30'
      assert_result rv, exp_exports(aqse: true,
        fl_export_payments: [:success], fl_export_refunds: [:success])

      # 1-off run by ex & en (I moved en from 00:41 to 00:40 to not have to run cron every minute but 5)
      rv = ce_run_at '00:40'
      assert_result rv,
        ex_export_payments: [:success], ex_export_refunds: [:success],
        en_export_payments: [:success], en_export_refunds: [:success]

      # 1-off run by tr - this happens only on a weekday, so if you're a poor soul working weekends
      # this test will fail to let you know you should be rollerskating or something instead
      rv = ce_run_at '00:45'
      assert_result rv, exp_exports

      # 2 by pa, one for failures and one for successes
      rv = ce_run_at '00:50'
      assert_result rv, pa_export_payments: [:success, :not_scheduled], pa_export_refunds: [:success, :not_scheduled]
      rv = ce_run_at '00:55'
      assert_result rv, pa_export_payments: [:not_scheduled, :success], pa_export_refunds: [:not_scheduled, :success]

      rv = ce_run_at '04:00'
      assert_result rv,exp_exports(aqse: true)

      # ========================= DAILY EXPORTS ==========================

      rv = ce_run_at '05:30'
      assert_result rv, exp_exports(aqse: true)

      rv = ce_run_at '05:45'
      assert_result rv, exp_exports

      # PB starts, 1h intervals
      rv = ce_run_at '06:00'
      assert_result rv, exp_exports(aqse: true, pb: true)

      rv = ce_run_at '06:15'
      assert_result rv, exp_exports

      # UT starts every 15 minutes
      rv = ce_run_at '06:30'
      assert_result rv, exp_exports(aqse: true)

      rv = ce_run_at '06:40'
      assert_result rv

      # another UT cycle in 15 minutes
      rv = ce_run_at '06:45'
      assert_result rv, exp_exports

      # UT, PB, AQ, SE, all at same time + 1-off by TD
      rv = ce_run_at '07:00'
      assert_result rv, exp_exports(aqse: true, pb: true,
        td_export_payments: [:success], td_export_refunds: [:success])

      # UT 15-min cycle
      rv = ce_run_at '07:15'
      assert_result rv, exp_exports

      # AQ/SE 30 min cycle + UT min
      rv = ce_run_at '07:30'
      assert_result rv, exp_exports(aqse: true)

      # 08:00 first OMNI & TRES export
      rv = ce_run_at '08:00'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true,
        cp_export_payments: [:success], cp_export_refunds: [:success],
        om_export_payments: [:success], om_export_refunds: [:success])

      # 09:50 DirectTV
      rv = ce_run_at '09:50'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true,
        dt_export_payments: [:success], dt_export_refunds: [:success],
      )

      # UT, PB, AQ, SE, all at same time + 1-off by DT
      rv = ce_run_at '11:00'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true,
        cp_export_payments: [:success], cp_export_refunds: [:success]
      )

      # 11:50 DirectTV
      rv = ce_run_at '11:50'
      assert_result rv, exp_exports(aqse: true, pb: false,
        dt_export_payments: [:success], dt_export_refunds: [:success],
      )

      # here's a late export running outside of schedule, runners failed
      # to execute from 11:00-12:30, export is attempted at next possible time
      rv = ce_run_at '12:30'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true)

      rv = ce_run_at '12:45'
      assert_result rv,
        ut_export_payments: [:success], ut_export_refunds: [:success],
        dp_export_payments: [:success], dp_export_refunds: [:success]

      # 13:50 DirectTV
      rv = ce_run_at '13:50'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true,
        dt_export_payments: [:success], dt_export_refunds: [:success],
      )

      # UT, PB, AQ, SE, all at same time + 1-off by DT & OM
      rv = ce_run_at '14:00'
      assert_result rv, exp_exports(aqse: false, pb: false, utdp: false,
        om_export_payments: [:success], om_export_refunds: [:success])

      rv = ce_run_at '14:15'
      assert_result rv,exp_exports

      rv = ce_run_at '14:17'
      assert_result rv

      # 15:00 CusanPedro
      rv = ce_run_at '15:00'
      assert_result rv, exp_exports(aqse: true, pb: true, tr: true,
        cp_export_payments: [:success], cp_export_refunds: [:success]
      )

      # 15:50 DirectTV
      rv = ce_run_at '15:50'
      assert_result rv, exp_exports(aqse: true, pb: false, tr: false,
        dt_export_payments: [:success], dt_export_refunds: [:success],
      )

      # UT, PB, AQ, SE, all at same time + 1-off by TD
      rv = ce_run_at '16:00'
      assert_result rv, exp_exports(aqse: false, pb: true, utdp: false, tr: true,
        td_export_payments: [:success], td_export_refunds: [:success])

      rv = ce_run_at '17:30'
      assert_result rv,exp_exports(aqse: true, pb: true, tr: true)

      rv = ce_run_at '18:00'
      assert_result rv, exp_exports(aqse: true,
        om_export_payments: [:success], om_export_refunds: [:success])

      rv = ce_run_at '18:30'
      assert_result rv, exp_exports(aqse: true, tr: true,
        pb_export_payments: [:success], pb_export_refunds: [:success])

      rv = ce_run_at '20:30'
      assert_result rv, exp_exports(aqse: true, pb: true)
      rv = ce_run_at '21:00'
      assert_result rv, exp_exports(aqse: true)

      # PB stops
      rv = ce_run_at '22:00'
      assert_result rv, exp_exports(aqse: true, pb: true)
      rv = ce_run_at '22:30'
      assert_result rv, exp_exports(aqse: true)

      # 1-off run by DT
      rv = ce_run_at '23:00'
      assert_result rv, exp_exports(aqse: true,
        mx_export_payments: [:success], mx_export_refunds: [:success],
      )
    end


    private

    def assert_result rv, expectations = {}
      rv = rv.clone

      expectations.each do |task, exps|
        result = rv.delete(task)
        flunk "expected a result on task #{task}, got #{rv}" unless result

        exps.each_with_index do |exp, idx|
          e = result.shift
          flunk "expected a result on task #{task} #{idx}, got #{e}" unless e

          if exp.is_a?(Class) and exp <= Exception
            if e.class < Exception
              assert_equal exp, e.class, "#{task} #{idx}: exception class is wrong, got #{result.class}:#{e.message}\n#{e.backtrace}'"
            else
              flunk "#{task} #{idx}: not an exception, got #{e.class} #{e.inspect}"
            end
          elsif exp == :success
            flunk "expected a success class, got #{e.class} #{e.inspect}" unless e.class.included_modules.include?(Importers::TransactionHelpers)

            refute e.error, "expected no error, got #{e.error}"
          elsif exp == :not_scheduled
            flunk "expected a NotScheduled class, got #{e.class} #{e.inspect}" unless e.class == PeriodicCronTask::NotScheduled
          else
            raise "#{task} #{idx}: don't know what to do with expectation #{exp.class} #{exp.inspect}"
          end
        end

        flunk "more things happened then expected: #{result}" if !result.empty?
      end

      rv.each do |task, results|
        results.each_with_index do |result, idx|
          assert result.is_a?(PeriodicCronTask::NotScheduled), "#{task} #{idx}: should not have been executed, but it resulted with #{result.class} '#{result.inspect}'"
        end
      end
    end

    def ce_run_at time
      current_time = Time.parse(time)
      raise "#{current_time} is before #{@last_time}! The consistency of time has been broken!" if @last_time > current_time

      Timecop.freeze current_time

      @ce = Pagafasil::CronExporter.new
      @ce.root_output_folder = files_path
      @ce.export_all
      @last_time = Time.parse(time)

      return @ce.result
    end

    def exp_exports(exports = {})
      aqse_present = exports.delete(:aqse)
      pb_present = exports.delete(:pb)
      tr_present = exports.delete(:tr)
      utdp_present = exports.has_key?(:utdp) ? exports.delete(:utdp) : true
      rv = {}

      if aqse_present
        rv.merge!(
          # ae_old_export_payments: [:success], ae_old_export_refunds: [:success],
          ae_export_payments: [:success], ae_export_refunds: [:success],
          # se_old_export_payments: [:success], se_old_export_refunds: [:success],
          se_export_payments: [:success], se_export_refunds: [:success],
        )
      end

      if pb_present
        rv.merge!(pb_export_payments: [:success], pb_export_refunds: [:success])
      end

      if tr_present
        rv.merge!(tr_export_payments: [:success], tr_export_refunds: [:success])
      end

      if utdp_present
        rv.merge!(
          ut_export_payments: [:success], ut_export_refunds: [:success],
          dp_export_payments: [:success], dp_export_refunds: [:success]
        )
      end

      rv.merge!(exports)

      rv
    end

  end
end
