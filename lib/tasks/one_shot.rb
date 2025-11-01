namespace :one_shot do

  task :find_double_exported_trxs_in_adjacent_batches => :environment do
    DB.loggers = []

    puts ['Operator Code', 'File Type', 'File ID', 'Transaction ID', 'Amount'].join(",")
    Operator.each do |op|
      ['payment', 'refund'].each do |file_type|
        last_max_id = nil

        FileExchangeLog.
          where(operator_code: op.code, file_type: file_type, status: 'processed').
          exclude(trx_max_id: nil, trx_min_id: nil).order(:id).
          select(:id, :operator_code, :file_type, :started_at, :trx_min_id, :trx_max_id).
          use_cursor.each do |fe|
            if last_max_id == fe.trx_min_id
              t = Transaction[last_max_id]
              puts [fe.operator_code, fe.file_type, fe.id, fe.trx_min_id, t.amount.to_f/100].join(",")
            end
            last_max_id = fe.trx_max_id
        end
      end
    end
  end

  task :regenerate_all_daily_merchant_reports => :environment do
    DB.loggers = []

    files_path = ENV['MERCHANT_REPORTS_FOLDER'] || '/var/tmp/merchant_reports'
    to_str = ->(x){ x.strftime("%Y%m%d") }

    start_time   = Transaction.min(:created_at)
    end_time     = Time.now

    puts "Exporting transactions from #{to_str[start_time]} to #{to_str[end_time]}"
    puts

    report_time = start_time
    while to_str[report_time] != to_str[end_time]
      printf "Exporting #{to_str[report_time]} => "
      Importers::Pagafasil::MerchantDailyReports.new(report_time, :payment,files_path + "/QB").export
      printf "payments "
      Importers::Pagafasil::MerchantDailyReports.new(report_time, :refund, files_path + "/QB").export
      printf "refunds "

      report_time += 24*60*60
      puts
    end
  end

  task :wipe_SE_balances_and_replace_them_with_zerofied_AQ_balances => :environment do
    DB.loggers = []

    puts "1. delete old SE balances"
    rv = Customer.where(operator_code: 'se').delete
    puts "  * deleted #{rv} record"

    puts "2. copy existing AQ balances as zero-balance SE balances"
    rv = 0
    batch = []
    Customer.where(operator_code: 'ae').each do |ae_customer|
      se_customer = Customer.new(ae_customer.values.except(:id))
      se_customer.operator_code = 'se'
      se_customer.balance = 0
      se_customer.due_balance = 0
      batch << se_customer
      rv += 1

      if rv % 1000 == 0
        Customer.multi_insert batch
        puts "  * inserted #{rv} records"
        batch = []
      end
    end

    Customer.multi_insert batch
    puts "  * inserted #{rv} records"
  end


end