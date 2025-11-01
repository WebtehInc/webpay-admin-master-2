require_relative "../pagafasil_importers/importer_helper"

module PagafasilImporters
  class TestCashierMonthlyReports < ImporterTest

    def setup
      super

      freeze_time
      reset_sequences
      mock_transactions_for_POS_exports(add_quickbooks_report_trxs: true)
    end

    def test_simple_export
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      rv = Importers::Pagafasil::CashierMonthlyReports.new(Time.now, files_path).export
      assert_equal 3, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder, got: ' + Dir.glob(files_path + "/*").join(', ')

      assert_equal_files 'test/fixtures/file_exports/merchant_reports/cashier_report_merchant_1',
        "#{rv[:output_dir]}/12345_Merchant_1.csv"

      assert_equal_files 'test/fixtures/file_exports/merchant_reports/cashier_report_merchant_2',
        "#{rv[:output_dir]}/54321_Merchant_2.csv"

      assert_equal_files 'test/fixtures/file_exports/merchant_reports/cashier_report_merchant_3',
        "#{rv[:output_dir]}/99999_Merchant_with_no_Transactions_inc_.csv"
    end


    private

  end
end