module Pagafasil
  class CronImporter

    attr_accessor :root_input_folder
    attr_reader :result

    def initialize
      @futures = {}
      @root_input_folder = ENV['PAGAFASIL_IMPORTS_FOLDER'] || '/var/tmp/pagafasil/import'
    end
    
    def import_all
      DB.loggers = []

      import Importers::Pagafasil::AquaelectraSelikorBalances, 'ae'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'bt'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'cp'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'di'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'dp'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'dt'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'en'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'ex'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'ff'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'fk'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'fl'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'ko'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'mx'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'om'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'pb'
      import Importers::Pagafasil::AquaelectraSelikorBalances, 'se'
      import Importers::Pagafasil::TdsBalances, 'td'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'tr'
      import Importers::Pagafasil::StandardBillPaymentBalances, 'ut'

      # Wait until jobs are finished
      wait_for_tasks_to_finish
    end


    private

    def import klass, operator_code, options = {}
      operator = Operator.where(code: operator_code).first
      every = options.delete(:every) || 1*60
      working_times = options.delete(:working_times) || ['00:00-24:00']

      file_folder = "#{root_input_folder}/#{operator.name}"
      FileUtils.mkdir_p file_folder rescue nil
      file_mask = "#{file_folder}/*"
      # file_name = Dir.glob(file_mask).min_by{|f| File.mtime(f)}

      task = "#{operator_code}_import_balances".to_sym
      @futures[task] ||= []
      @futures[task] << PeriodicCronTask.async_call(task, every: every, working_times: working_times) do
        klass.import_balances(file_mask, operator_code)
      end
    end

    def wait_for_tasks_to_finish
      @result = Hash[
        @futures.map{ |id, f| [id, f.map(&:value)] }
      ]
    end

  end
end
