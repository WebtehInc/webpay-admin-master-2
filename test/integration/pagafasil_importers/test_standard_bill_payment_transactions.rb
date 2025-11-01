require_relative "../pagafasil_importers/importer_helper"

module PagafasilImporters
  class TestStandardBillPaymentTransactions < ImporterTest

    def setup
      super

      @op_ae = Operator.create(:code=>"ae", :name=>"UTS",  :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"ECNV", :file_exchange_reference_number=>nil, :bank_account_number=>3141592653) # bank acc: pi
      @op_ch = Operator.create(:code=>"ch", :name=>"Roko", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"FOOB", :file_exchange_reference_number=>nil, :bank_account_number=>2718281828) # bank acc: e

      freeze_time
      reset_sequences
      Importers::TransactionHelpers.mock_transactions_for_operator_exports 'ch', 'ae'
    end

    def test_when_no_transactions
      DB[:transactions].delete

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      # no transactions, no files:
      ch_p = Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHP', :payment, files_path)
      ch_r = Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHR', :refund,  files_path)
      assert_equal 0, Dir.glob(files_path + "/**/*").select{ |fn| File.file?(fn) }.count, 'wrong number of files found in export folder'
    end

    def test_simple_export
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      ch_p = Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHP', :payment, files_path)
      ch_r = Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHR', :refund,  files_path)

      ae_p = Importers::Pagafasil::StandardBillPaymentTransactions.export('ae', 'AP', :payment, files_path)
      ae_r = Importers::Pagafasil::StandardBillPaymentTransactions.export('ae', 'AR', :refund,  files_path)

      assert_equal 2, Dir.glob(files_path + "/payment/*").count, 'wrong number of files found in payment export folder'
      assert_equal 2, Dir.glob(files_path + "/refund/*").count, 'wrong number of files found in refund export folder'

      assert_basic_export_attributes ch_p, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_CHP.trx',
        status: 'processed', operator: @op_ch, file_type: 'payment', trxs: 2, balance: 40_00,
        file_reference: 1, company_id: 'CHP', file_mask: /payment\/CHP[0-9]{10}/

      assert_basic_export_attributes ae_p, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_AEP.trx',
        status: 'processed', operator: @op_ae, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'AP', file_mask: /payment\/AP[0-9]{10}/

      assert_basic_export_attributes ch_r, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_CHR.trx',
        status: 'processed', operator: @op_ch, file_type: 'refund', trxs: 1, balance: 10_00,
        file_reference: 2, company_id: 'CHR', file_mask: /refund\/CHR[0-9]{10}/

      assert_basic_export_attributes ae_r, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_AER.trx',
        status: 'processed', operator: @op_ae, file_type: 'refund', trxs: 1, balance: 20_00,
        file_reference: 2, company_id: 'AR', file_mask: /refund\/AR[0-9]{10}/

      assert_equal 2+4+1+1, Transaction.where(status: 'approved').count, 'trx count is off'

      # what happens if we reexport one of the files?
      ae_p2 = Importers::Pagafasil::StandardBillPaymentTransactions.export('ae', 'AP', :payment, files_path, reexport_file_id: ae_p.file_exchange_log.id)

      assert_basic_export_attributes ae_p2, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_AEP.trx',
        status: 'processed', operator: @op_ae, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'AP'
    end

    def test_legacy_export_with_ALP_header
      op_ut = Operator.create(:code=>"ut", :name=>"Roko", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"FOOB", :file_exchange_reference_number=>nil, :bank_account_number=>2718281828) # bank acc: e
      Importers::TransactionHelpers.mock_transactions_for_operator_exports 'ut', 'ae'

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      ut_p = Importers::Pagafasil::StandardBillPaymentTransactions.export('ut', 'UTP', :payment, files_path)
      ut_r = Importers::Pagafasil::StandardBillPaymentTransactions.export('ut', 'UTR', :refund,  files_path)

      assert_equal 1, Dir.glob(files_path + "/payment/*").count, 'wrong number of files found in payment export folder'
      assert_equal 1, Dir.glob(files_path + "/refund/*").count, 'wrong number of files found in refund export folder'

      assert_basic_export_attributes ut_p, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_legacy_export_with_ALP_header_UTP.trx',
        status: 'processed', operator: op_ut, file_type: 'payment', trxs: 2, balance: 40_00,
        file_reference: 1, company_id: 'UTP', file_mask: /payment\/UTP[0-9]{10}/

      assert_basic_export_attributes ut_r, 'test/fixtures/file_exports/pagafasil/standard_bill_payment_legacy_export_with_ALP_header_UTR.trx',
        status: 'processed', operator: op_ut, file_type: 'refund', trxs: 1, balance: 10_00,
        file_reference: 2, company_id: 'UTR', file_mask: /refund\/UTR[0-9]{10}/
    end


    private

  end
end