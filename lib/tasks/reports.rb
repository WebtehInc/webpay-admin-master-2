namespace :reports do

  task :cashier_monthly_report => :environment do
    Importers::Pagafasil::CashierMonthlyReports.new(report_time, files_path + "/CASHIER/#{report_time.strftime("%b%Y").upcase}").export
  end

  task :merchant_daily_report => 'reports:merchant_daily_reports:all'

  namespace :merchant_daily_reports do
    multitask :all => [:payment, :refund]
    task :payment => :environment do
      Importers::Pagafasil::MerchantDailyReports.new(report_time, :payment,files_path + "/QB").export
    end
    task :refund => :environment do
      Importers::Pagafasil::MerchantDailyReports.new(report_time, :refund, files_path + "/QB").export
    end
  end


  private

  def files_path
    ENV['MERCHANT_REPORTS_FOLDER'] || '/var/tmp/merchant_reports'
  end

  # MERCHANT_REPORTS_DATE=20161022 or
  # MERCHANT_REPORTS_DAYS_AGO=1
  def report_time
    Importers::ResolveTimeForCronReports[ENV]
  end

end