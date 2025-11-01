require_relative "../pagafasil_importers/importer_helper"
require 'active_support'

module PagafasilImporters
  class TestMerchantDailyReports < ImporterTest

    def setup
      super

      freeze_time
      reset_sequences
      mock_transactions_for_POS_exports(add_quickbooks_report_trxs: true)
    end

    def test_simple_export
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      rv_p = Importers::Pagafasil::MerchantDailyReports.new(Time.now, :payment, files_path).export
      rv_r = Importers::Pagafasil::MerchantDailyReports.new(Time.now, :refund, files_path).export
      assert_equal 2, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder, got: ' + Dir.glob(files_path + "/*").join(', ')

      assert_equal_files 'test/fixtures/file_exports/merchant_reports/merchant_daily_report_merchant_sale',
        File.join(rv_p[:output_dir], "20100921_sale.csv")

      assert_equal_files 'test/fixtures/file_exports/merchant_reports/merchant_daily_report_merchant_refund',
        File.join(rv_r[:output_dir], "20100921_reversal.csv")
    end


    private

  end
end
