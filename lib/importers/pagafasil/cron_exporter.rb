module Pagafasil
  class CronExporter

    attr_accessor :root_output_folder
    attr_reader :result

    def initialize
      @root_output_folder = ENV['PAGAFASIL_EXPORTS_FOLDER'] || '/var/tmp/pagafasil/export'
      @futures = {}
    end


    # run everything, it's intended to be run from cron every five minutes this is a list of
    # all operator codes & their schedules:
    #
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

    def export_all
      wday = Time.now.wday

      #   ["ae", "Aquaelectra"],                 # Daily every 30 minutes from 5:30am for 12 hours
      export Importers::Pagafasil::AquaelectraSelikorTransactions, 'ae',
        prefix: ['AQ2', 'AQ2'],
        every: 30*60

      #   ["cp", "CUSANPEDRO"],                  # Daily 12:10am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'cp', working_times: ['08:00', '11:00', '15:00'],
        prefix: ['CPP', 'CPR']

      #   ["di", "Districo"],                    # Daily 12:15am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'di', working_times: ['00:15'],
        prefix: ['DSP', 'DSR']

      #   ["dp", "Digicel Postpaid"]             # Daily every 15 minutes from 6:30am for 14 hours
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'dp', every: 15*60,
        prefix: ['DGP', 'DGR']

      #   ["dt", "DirecTV"],                     # Daily 9:50, 11:50, 13:50, 15:50, 20:50
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'dt',
        working_times: ['09:50', '11:50', '13:50', '15:50', '20:50'],
        prefix: ['DS', 'DR']

      #   ["en", "Entiero Na Kuota"],            # Daily 12:41am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'en', working_times: ['00:40'],
        prefix: ['EKP', 'EKR']

      #   ["ex", "Extura"],                      # Daily 12:40am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'ex', working_times: ['00:40'],
        prefix: ['EXP', 'EXR']

      #   ["ff", "FFP"],                         # Daily 12:20am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'ff', working_times: ['00:20'],
        prefix: ['FIP', 'FIR']

      #   ["fk", "FKP"],                         # Daily 12:20am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'fk', working_times: ['00:20'],
        prefix: ['FAP', 'FAR']

      #   ["fl", "FLOW"],                        # Daily 12:30am
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'fl', working_times: ['00:30'],
        prefix: ['FP', 'FR']

      #   ["ko", "Korpodeko"]                    # Daily midnight
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'ko', working_times: ['00:00'],
        prefix: ['KOP', 'KOR']

      #   ["mx", "MaxTV"]                    # Daily 11:00pm
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'mx', working_times: ['23:00'],
        prefix: ['MXP', 'MXR']

      #   ["om", "OMNI"]                         # Daily 8am, 2pm and 6pm
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'om', working_times: ['08:00', '14:00', '18:00'],
        prefix: ['OMP', 'OMR']

      #   ["pa", "Pagatinu"],                 # Daily 12:50 am
      export Importers::Pagafasil::PagatinuTransactions, 'pa', working_times: ['00:50'],
        prefix: ['SUCCESS', 'NO REFUNDS']
      export Importers::Pagafasil::PagatinuTransactions, 'pa', working_times: ['00:55'],
        prefix: ['FAIL', 'NO REFUNDS']

      #   ["pb", "Paga Bo But"],                 # Daily Every hour from 6am for 16 hours
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'pb', every: 60*60, working_times: ['06:00-22:00'],
        prefix: ['BP', 'BR']

      #   ["se", "Selikor"],                     # Daily every 30 minutes from 5:30am for 12 hours
      export Importers::Pagafasil::AquaelectraSelikorTransactions, 'se', every: 30*60,
        prefix: ['SE2', 'SE2']

      #   ["td", "TDS"],                         # Daily 7am and 4pm
      export Importers::Pagafasil::TdsTransactions, 'td', working_times: ['07:00', '16:00']

      #   ["tr", "TRES"],                        # Hourly, beginning at 8am and ending at 8pm.
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'tr', every: 60*60, working_times: ['08:00-20:00'],
        prefix: ['TSS', 'TSR']

      #   ["ut", "UTS"]                          # Daily every 15 minutes from 6:30am for 14 hours
      export Importers::Pagafasil::StandardBillPaymentTransactions, 'ut', every: 15*60,
        prefix: ['AL', 'AR']

      # Wait until jobs are finished
      wait_for_tasks_to_finish
    end


    private

    def export klass, operator_code, options = {}
      operator = Operator.where(code: operator_code).first
      every = options.delete(:every) || 5*60
      working_times = options.delete(:working_times) || ['00:00-24:00']
      task_code = options.delete(:task) || operator_code

      # prefix is actually company_id in the exporter context
      prefix = options.delete(:prefix) ||
        [ operator_code.upcase + 'P', operator_code.upcase + 'R' ]

      task = "#{task_code}_export_payments".to_sym
      @futures[task] ||= []
      @futures[task] << PeriodicCronTask.async_call(task, every: every, working_times: working_times) do
        klass.export(operator_code, prefix[0], :payment, "#{root_output_folder}/#{operator.name}")
      end

      task = "#{task_code}_export_refunds".to_sym
      @futures[task] ||= []
      @futures[task] << PeriodicCronTask.async_call(task, every: every, working_times: working_times) do
        klass.export(operator_code, prefix[1], :refund,  "#{root_output_folder}/#{operator.name}")
      end
    end

    def wait_for_tasks_to_finish
      @result = Hash[
        @futures.map{ |id, f| [id, f.map(&:value)] }
      ]
    end

  end
end