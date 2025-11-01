module Importers::Pagafasil
  class CashierMonthlyReports

    include Importers::Helpers
    include Importers::QuickBookHelpers

    EOL_CHAR = "\r\n"
    DELIMITER = "\t"
    REPORT_DIR = 'cashier_monthly_reports'

    attr_accessor :date

    def initialize(date, output_dir)
      @date = date

      # one month range
      @start_date = Time.new(date.year, date.month, 1)
      end_date = Time.new(date.year, date.month + 1, 1) - 1 # one second before midnight of first day in next month
      @date_range = @start_date..end_date                   # 2016-10-01 00:00:00 +0200  ... 2016-10-31 23:59:59 +0100
      @output_dir = output_dir

      @files = {}
      @export_time = Time.now
      @base_dir = build_base_dir REPORT_DIR, :in_progress

      FileUtils.mkdir_p @output_dir
    end

    def export
      Account.where(type: 'business').order(:merchant_name).each do |account|
        generate_output_for_merchant(account)
      end

      Dir[@base_dir+"/*"].each do |file_name|
        FileUtils.mv file_name, @output_dir
      end

      {
        base_dir: @base_dir,
        output_dir: @output_dir,
        files: @files,
        status: 'success'
      }
    rescue Exception => e
      log e

      {
        base_dir: @base_dir,
        output_dir: @output_dir,
        files: @files,
        status: 'error',
        exception: e
      }
    end

    def generate_output_for_merchant(account)
      file_name = "#{account.account_number}"
      file_name += "_#{account.merchant_name.gsub(/[ ,\.]/, '_')}" if account.merchant_name
      file_name += '.csv'
      @files[account.id] = file_name
      file = File.open(@base_dir + "/#{file_name}", 'w')
      @index = 0 # row index

      Terminal.where(account_id: account.id).order(:id).each do |terminal|
        generate_output_for_terminal(file, account, terminal)
      end
    ensure
      file.close if file and !file.closed?
    end

    def generate_output_for_terminal(file, account, terminal)
      Cashier.where(terminal_id: terminal.id).order(:full_name).each do |cashier|
        generate_output_for_cashier(file, account, terminal, cashier)
      end
    end

    def generate_output_for_cashier(file, account, terminal, cashier)
      rows = ''

      # fetch stats from DB
      operator_stats =  DB[:transactions___t].join(:operators___o, o__code: :t__operator_code).
                        join(:cashiers___c, c__id: :t__cashier_id).
                        where(t__transaction_type: ['bill_mpos', 'prepaid_mpos'], t__cashier_id: cashier.id, t__created_at: @date_range, t__voided: false, status: 'approved').
                        select_group(:o__code, :o__name, :t__services_batch_number).
                        select_append{sum(:t__amount).as(:total)}.
                        select_append{count(:t__id).as(:count)}.order(:c__full_name).order(:o__name).all

      # generate rows for merchant
      operator_stats = operator_stats.map do |stat|
        stat[:mapped_code] = build_operator_name(stat)
        stat
      end

      operator_stats.
        sort_by { |stat| stat[:mapped_code] }.
        each do |stat|
          @index = @index + 1
          rows << [ @index,
            account.merchant_name.to_s.gsub(DELIMITER, '_'),
            @start_date.strftime('%d/%m/%Y'),
            account.account_number,
            terminal.id,
            cashier.full_name,
            stat[:mapped_code],
            "%.2f" % (stat[:total]/100.0).to_s,
            stat[:count]].join(DELIMITER)
          rows << EOL_CHAR
        end

      file.write(rows)
    end

    def build_base_dir report_subdir, working_subdir
      raise "unknown :dir option '#{working_subdir}'" unless Importers::WORKING_SUBDIRECTORIES.include?(working_subdir.to_s)

      dir_name = Importers::ROOT_DIRECTORY
      dir_name += "/#{working_subdir}"
      dir_name += "/#{report_subdir}"
      dir_name += "/#{@start_date.strftime("%Y%m%d")}-#{SecureRandom.uuid}" unless dir_name =~ Importers::Helpers::UUID_REGEX # add UUID if necessary
      FileUtils.mkdir_p dir_name

      dir_name
    end

  end
end

