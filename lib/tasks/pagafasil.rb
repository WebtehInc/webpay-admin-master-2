namespace :pagafasil do

  task :import => :environment do
    ci = Pagafasil::CronImporter.new
    ci.import_all
  end

  task :export => :environment do
    ce = Pagafasil::CronExporter.new
    ce.export_all
  end

  task :send_daily_report_to_operators => :environment do
    Operator.map do |o|
      future = Concurrent::Future.execute do
        unless o.email.present?
          "SKIPPING, operator doesn't have an e-mail"
        else
          Mailer.sendmail("/operator/export", o, Date.today - 1)
          "SENT report to #{o.name} (#{o.email})"
        end
      end

      [o, future]
    end.each do |rv|
      o, future = rv

      if future.rejected?
        puts "#{o.name}: #{future.exception}"
        puts future.exception.backtrace.join("\n")
      else
        puts "#{o.name}: #{future.value}"
      end
    end
  end


  # To do:
  #   Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHP', :payment, '/tmp')      or
  #   Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHR', :refund, '/tmp')
  #
  # You need to run:
  #   rake 'pagafasil:export_transactions[StandardBillPaymentTransactions,ch,CHP,payment,/tmp]'        or
  #   rake 'pagafasil:export_transactions[StandardBillPaymentTransactions,ch,CHR,refund,/tmp]'
  #
  desc "export pagafasil transaction files"
  task :export_transactions, [:class_name, :operator_code, :company_id, :export_type, :output_folder] => :environment do |t, args|
    class_name = "Importers::Pagafasil::" + args[:class_name]
    operator_code = args[:operator_code]
    company_id = args[:company_id]
    export_type = args[:export_type]
    output_folder = args[:output_folder]

    klass = class_name.constantize

    klass.export operator_code, company_id, export_type, output_folder
  end

  # To do:
  #   Importers::Pagafasil::StandardBillPaymentBalances.import_balances("/tmp/WebPay_balances_mock*")
  #
  # You need to run:
  #   rake 'pagafasil:import_balances[StandardBillPaymentBalances,ch,/tmp/WebPay_balances_mock*]'
  #
  desc "import pagafasil import files"
  task :import_balances, [:class_name, :operator_code, :file_mask] => :environment do |t, args|
    class_name = "Importers::Pagafasil::" + args[:class_name]
    operator_code = args[:operator_code]
    file_mask = args[:file_mask]

    klass = class_name.constantize

    klass.import_balances file_mask
  end

end
