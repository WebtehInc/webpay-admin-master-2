module Importers::Pagafasil
  class MerchantDailyReports

    # FOR QUICKBOOKS IMPORT

    include Importers::Helpers
    include Importers::QuickBookHelpers

    EOL_CHAR = "\r\n"
    DELIMITER = ","
    DEFAULT_FIELD = '1300 - Debiteuren (sub)'
    REPORT_DIR = 'merchant_daily_reports'

    attr_accessor :date, :file, :type

    def initialize(date, type, output_dir)
      @date = date
      @type = type

      # one day range
      @midnight = Time.new(date.year, date.month, date.day)
      next_midnight = Time.new(date.year, date.month, date.day)+1.day
      @date_range = @midnight...next_midnight
      @output_dir = output_dir

      @index = 0 # row index

      @export_time = Time.now
      @base_dir = build_base_dir REPORT_DIR, :in_progress

      FileUtils.mkdir_p @output_dir
    end

    def export
      if type == :payment
        file_type = 'sale'
      elsif type == :refund
        file_type = 'reversal'
      else
        throw '????'
      end

      @file = File.open(@base_dir + "/#{@midnight.strftime("%Y%m%d")}_#{file_type}.csv", 'w')

      Account.where(type: 'business').order(:merchant_name).each do |account|
        generate_output_for_merchant(account)
      end

      Dir[@base_dir+"/*"].each do |file_name|
        FileUtils.mv file_name, @output_dir
      end

      {
        base_dir: @base_dir,
        output_dir: @output_dir,
        status: 'success'
      }
    rescue Exception => e
      log e

      {
        base_dir: @base_dir,
        output_dir: @output_dir,
        status: 'error',
        exception: e
      }

    ensure
      file.close if file and !file.closed?

    end

    def generate_output_for_merchant(account)
      if type == :payment
        trx_type = ['bill_mpos', 'prepaid_mpos']
      elsif type == :refund
        trx_type = ['bill_reversal_mpos']
      else
        throw '????'
      end

      # generate rows for merchant
      generate_rows_for_merchant(file, account, trx_type)
    end

    # row: merchant_name date default merchant_id total average count operator_name
    def generate_rows_for_merchant(file, account, trx_type)
      merchant_data_rows = ''

      # dataset is array of:
      #   {:name=>"Operator 1", :code=>"op1", :total=>4000, :average=>#<BigDecimal:4cf7958,'0.2E4',9(36)>, :count=>2}
      # out of which we need:
      #   * :code, :name (of operator)
      #   * count (of trx)
      #   * total (of trx, in cents)

      lodgments = DB[:services_lodgments].
        where(account_id: account.id, created_at: @date_range).
        order(:account_id, :created_at).
        all

      lodgments.each do |lodgment|
        # fetch stats from DB
        # puts "exporting lodgment #{{type: type, services_batch_number: lodgment[:batch_number], terminal_id: lodgment[:terminal_id]}}"
        dataset =
          DB[:transactions___t].join(:operators___o, code: :operator_code).
            where(services_batch_number: lodgment[:batch_number], terminal_id: lodgment[:terminal_id]).
            where(t__transaction_type: trx_type, status: 'approved').
            select_group(:o__name, :o__code, :t__terminal_id, :t__services_batch_number).
            select_append{sum(:t__amount).as(:total)}.
            select_append{avg(:t__amount).as(:average)}.
            select_append{count(:t__id).as(:count)}.
            order(:t__terminal_id, :t__services_batch_number, :o__code).
            all

        dataset.each do |stat|
          @index = @index + 1
          # puts "  * stats: #{{index: @index, operator: stat[:code], count: stat[:count], total: stat[:total]}}"
          merchant_data_rows << [
            @index,
            account.merchant_name.to_s.gsub(DELIMITER, '_'),
            @midnight.strftime('%m-%d-%Y'),
            DEFAULT_FIELD,
            account.account_number,
            "%.2f" % (stat[:total]/100.0).to_s,
            stat[:count],
            build_operator_name(stat),

          ].
            join(DELIMITER)
          merchant_data_rows << EOL_CHAR
        end
      end

      file.write(merchant_data_rows)
    end

    def build_base_dir report_subdir, working_subdir
      raise "unknown :dir option '#{working_subdir}'" unless Importers::WORKING_SUBDIRECTORIES.include?(working_subdir.to_s)

      dir_name = Importers::ROOT_DIRECTORY
      dir_name += "/#{working_subdir}"
      dir_name += "/#{report_subdir}"
      dir_name += "/#{@midnight.strftime("%Y%m%d")}-#{SecureRandom.uuid}" unless dir_name =~ Importers::Helpers::UUID_REGEX # add UUID if necessary
      FileUtils.mkdir_p dir_name

      dir_name
    end

  end
end

