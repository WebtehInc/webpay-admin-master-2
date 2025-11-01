require_relative "../pagafasil_importers/importer_helper"

module PagafasilImporters
  class TestTdsTransactions < ImporterTest

    def setup
      super

      @op_ae = Operator.create(:code=>"ae", :name=>"Aquaelectra",  :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"AQ", :file_exchange_reference_number=>nil, :bank_account_number=>3141592653) # bank acc: pi
      @op_td = Operator.create(:code=>"td", :name=>"TDS", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"SE", :file_exchange_reference_number=>nil, :bank_account_number=>2718281828) # bank acc: e

      freeze_time
      reset_sequences
      Importers::TransactionHelpers.mock_transactions_for_operator_exports('ae', 'td')
    end

    def test_when_no_transactions
      DB[:transactions].delete

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      # no transactions, no files:
      td_p = Importers::Pagafasil::TdsTransactions.export('td', 'SEP', :payment, files_path)
      td_r = Importers::Pagafasil::TdsTransactions.export('td', 'SER', :refund,  files_path)
      assert_equal 0, Dir.glob(files_path + "/**/*").select{ |fn| File.file?(fn) }.count, 'wrong number of files found in export folder'
      assert_equal 0, FileExchangeLog.count, 'expected no file exchange log records'
    end

    def test_simple_export
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      td_p = Importers::Pagafasil::TdsTransactions.export('td', 'SEP', :payment, files_path)
      td_r = Importers::Pagafasil::TdsTransactions.export('td', 'SER', :refund,  files_path)

      assert_equal 2, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      assert_basic_export_attributes td_p, 'test/fixtures/file_exports/pagafasil/TDS_SEP.trx',
        status: 'processed', operator: @op_td, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'SEP',
        file_mask: /payment\/TD[0-9]{8}pay.dta/

      assert_basic_export_attributes td_r, 'test/fixtures/file_exports/pagafasil/TDS_SER.trx',
        status: 'processed', operator: @op_td, file_type: 'refund', trxs: 1, balance: 20_00,
        file_reference: 2, company_id: 'SER',
        file_mask: /refund\/TD[0-9]{8}rpy.dta/

      assert_equal 2+3+1+1+1, Transaction.where(status: 'approved').count, 'trx count is off'

      # what happens if we reexport one of the files?
      td_p2 = Importers::Pagafasil::TdsTransactions.export('td', 'SEP', :payment, files_path, reexport_file_id: td_p.file_exchange_log.id)

      assert_basic_export_attributes td_p2, 'test/fixtures/file_exports/pagafasil/TDS_SEP.trx',
        status: 'processed', operator: @op_td, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'SEP'
    end


    private


  end
end