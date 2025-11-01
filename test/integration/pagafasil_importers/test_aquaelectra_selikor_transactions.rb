require_relative "../pagafasil_importers/importer_helper"

module PagafasilImporters
  class TestAquaelectraSelikorTransactions < ImporterTest

    def setup
      super

      @op_ae = Operator.create(:code=>"ae", :name=>"Aquaelectra",  :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"AQ", :file_exchange_reference_number=>nil, :bank_account_number=>3141592653) # bank acc: pi
      @op_se = Operator.create(:code=>"se", :name=>"Selikor", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"SE", :file_exchange_reference_number=>nil, :bank_account_number=>2718281828) # bank acc: e

      freeze_time
      reset_sequences
    end

    def test_when_no_transactions
      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      # no transactions, no files:
      se_p = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :payment, files_path)
      se_r = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :refund,  files_path)
      assert_equal 0, Dir.glob(files_path + "/**/*").select{ |fn| File.file?(fn) }.count, 'wrong number of files found in export folder'
      assert_equal 0, FileExchangeLog.count, 'expected no file exchange log records'
    end

    def test_simple_export
      Importers::TransactionHelpers.mock_transactions_for_operator_exports('se', 'ae')

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      se_p = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :payment, files_path)
      se_r = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :refund,  files_path)

      ae_p = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :payment, files_path)
      ae_r = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :refund,  files_path)

      assert_equal 2, Dir.glob(files_path + "/payment/*").count, 'wrong number of files found in payment export folder'
      assert_equal 2, Dir.glob(files_path + "/refund/*").count, 'wrong number of files found in refund export folder'

      assert_basic_export_attributes se_p, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_SEP.trx',
        status: 'processed', operator: @op_se, file_type: 'payment', trxs: 2, balance: 40_00,
        file_reference: 1, company_id: 'SE',
        file_mask: /payment\/20100921151022_PFSSEL_0000001.TXT/
      assert_basic_export_attributes ae_p, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_AEP.trx',
        status: 'processed', operator: @op_ae, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'AQ',
        file_mask: /payment\/20100921151022_PFSAQUA_0000001.TXT/

      assert_basic_export_attributes se_r, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_SER.trx',
        status: 'processed', operator: @op_se, file_type: 'refund', trxs: 1, balance: 10_00,
        file_reference: 2, company_id: 'SE',
        file_mask: /refund\/20100921151022_PFSSEL_0000002.TXT/

      assert_basic_export_attributes ae_r, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_AER.trx',
        status: 'processed', operator: @op_ae, file_type: 'refund', trxs: 1, balance: 20_00,
        file_reference: 2, company_id: 'AQ',
        file_mask: /refund\/20100921151022_PFSAQUA_0000002.TXT/

      assert_equal 2+3+1+1+1, Transaction.where(status: 'approved').count, 'trx count is off'

      # what happens if we reexport one of the files?
      ae_p2 = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :payment, files_path, reexport_file_id: ae_p.file_exchange_log.id)

      assert_basic_export_attributes ae_p2, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_AEP.trx',
        status: 'processed', operator: @op_ae, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 1, company_id: 'AQ'
    end

    # the idea here is to prevent double export of transactions if timestamps aren't trustable to separate batches
    def test_export_with_frozen_time
      DB.loggers = []

      Importers::TransactionHelpers.mock_transactions_for_operator_exports('se', 'ae')

      assert_equal 0, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      se_p1 = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :payment, files_path)
      se_r1 = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :refund,  files_path)

      ae_p1 = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :payment, files_path)
      ae_r1 = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :refund,  files_path)

      assert_equal 2, Dir.glob(files_path + "/payment/*").count, 'wrong number of files found in payment export folder'
      assert_equal 2, Dir.glob(files_path + "/refund/*").count, 'wrong number of files found in refund export folder'

      Importers::TransactionHelpers.mock_transactions_for_operator_exports('se', 'ae')

      assert_equal 2, Dir.glob(files_path + "/*").count, 'wrong number of files found in export folder'

      se_p = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :payment, files_path)
      se_r = Importers::Pagafasil::AquaelectraSelikorTransactions.export('se', 'SE', :refund,  files_path)

      ae_p = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :payment, files_path)
      ae_r = Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AQ', :refund,  files_path)

      assert_equal 4, Dir.glob(files_path + "/payment/*").count, 'wrong number of files found in payment export folder'
      assert_equal 4, Dir.glob(files_path + "/refund/*").count, 'wrong number of files found in refund export folder'

      assert_basic_export_attributes se_p, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_SEP_2.trx',
        status: 'processed', operator: @op_se, file_type: 'payment', trxs: 2, balance: 40_00,
        file_reference: 2+1, company_id: 'SE',
        file_mask: /payment\/20100921151022_PFSSEL_0000003.TXT/
      assert_basic_export_attributes ae_p, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_AEP_2.trx',
        status: 'processed', operator: @op_ae, file_type: 'payment', trxs: 4, balance: 130_00,
        file_reference: 2+1, company_id: 'AQ',
        file_mask: /payment\/20100921151022_PFSAQUA_0000003.TXT/

      assert_basic_export_attributes se_r, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_SER_2.trx',
        status: 'processed', operator: @op_se, file_type: 'refund', trxs: 1, balance: 10_00,
        file_reference: 2+2, company_id: 'SE',
        file_mask: /refund\/20100921151022_PFSSEL_0000004.TXT/

      assert_basic_export_attributes ae_r, 'test/fixtures/file_exports/pagafasil/aquaelectra_selikor_AER_2.trx',
        status: 'processed', operator: @op_ae, file_type: 'refund', trxs: 1, balance: 20_00,
        file_reference: 2+2, company_id: 'AQ',
        file_mask: /refund\/20100921151022_PFSAQUA_0000004.TXT/

      assert_equal (2+3+1+1+1)*2, Transaction.where(status: 'approved').count, 'trx count is off'
    end


    private

  end
end