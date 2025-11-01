require_relative "../pagafasil_importers/importer_helper"
require 'active_support/core_ext/numeric'

module PagafasilImporters
  class TestPagatinuTransactions < ImporterTest

    def setup
      super

      @op_ae = Operator.create(:code=>"ae", :name=>"Aquaelectra",  :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"AQ", :file_exchange_reference_number=>nil, :bank_account_number=>3141592653) # bank acc: pi
      @op_se = Operator.create(:code=>"se", :name=>"Selikor", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"SE", :file_exchange_reference_number=>nil, :bank_account_number=>2718281828) # bank acc: e

      freeze_time
      reset_sequences
      Importers::TransactionHelpers.mock_transactions_for_operator_exports('ae', 'se')

      Transaction.where(type: 'debit').delete
      Transaction.where(true).update(transaction_type: 'prepaid_mpos')
    end

    def test_when_no_transactions
      DB[:transactions].delete

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      # no transactions, no files:
      pa_p_s = Importers::Pagafasil::PagatinuTransactions.export('ae', 'SUCCESS', :payment, files_path)
      pa_p_f = Importers::Pagafasil::PagatinuTransactions.export('ae', 'FAIL',    :payment, files_path)
      pa_r = Importers::Pagafasil::PagatinuTransactions.export('ae', 'NO REFUNDS', :refund,  files_path)
      assert_equal 0, Dir.glob(files_path + "/**/*").select{ |fn| File.file?(fn) }.count, 'wrong number of files found in export folder'
      assert_equal 0, FileExchangeLog.count, 'expected no file exchange log records'
    end

    def test_simple_export
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      pa_p_s = Importers::Pagafasil::PagatinuTransactions.export('ae', 'SUCCESS', :payment, files_path)
      Timecop.travel 5.minutes
      pa_p_f = Importers::Pagafasil::PagatinuTransactions.export('ae', 'FAIL',    :payment, files_path)
      Timecop.travel 5.minutes
      pa_r = Importers::Pagafasil::PagatinuTransactions.export('ae', 'NO REFUNDS', :refund,  files_path)

      assert_equal 2, Dir.glob(files_path + "/*").count, 'wrong number of files found in payment export folder'

      assert_basic_export_attributes pa_p_s, 'test/fixtures/file_exports/pagafasil/pagatinu_payment_SUCCESS.trx',
        status: 'processed', operator: @op_ae, file_type: 'success', trxs: 2, balance: 40_00,
        file_reference: 1, company_id: 'SUCCESS',
        file_mask: /PSBPagatinu_[0-9]{8}_[0-9]{6}_S.csv/

      assert_basic_export_attributes pa_p_f, 'test/fixtures/file_exports/pagafasil/pagatinu_payment_FAIL.trx',
        status: 'processed', operator: @op_ae, file_type: 'fail', trxs: 1, balance: 60_00,
        file_reference: 2, company_id: 'FAIL',
        file_mask: /PSBPagatinu_[0-9]{8}_[0-9]{6}_F.csv/

      assert_nil pa_r.file, 'expected no refund file to happen'

      assert_equal 2+1+3, Transaction.where(status: 'approved').count, 'trx count is off'

      # what happens if we reexport one of the files?
      ae_p2 = Importers::Pagafasil::PagatinuTransactions.export('ae', 'SUCCESS', :payment, files_path, reexport_file_id: pa_p_s.file_exchange_log.id)

      assert_basic_export_attributes pa_p_s, 'test/fixtures/file_exports/pagafasil/pagatinu_payment_SUCCESS.trx',
        status: 'processed', operator: @op_ae, file_type: 'success', trxs: 2, balance: 40_00,
        file_reference: 1, company_id: 'SUCCESS',
        file_mask: /PSBPagatinu_[0-9]{8}_[0-9]{6}_S.csv/
    end


    private

  end
end
