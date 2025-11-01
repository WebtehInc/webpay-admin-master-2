require_relative "importer_helper"

module PagafasilImporters
  class TestStandardBillPaymentBalances < ImporterTest

    def setup
      super
      @operator = Operator.create(:code=>"wtf", :name=>"UTS", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"ECNV", :file_exchange_reference_number=>nil, :bank_account_number=>nil)
    end

    def test_deterministic_import_result
      create_mock 'file1', nil
      create_mock 'file2', nil

      assert_equal 0, Customer.count, 'expected blank db'
      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 2, rv.count, 'expected 2 files to have been processed'

      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 2, updates: 0, customers: 2

      customer = Customer.order(:id).first
      assert_equal 4200, customer.balance, "customer balance is wrong"
      assert_equal "TBD", customer.currency, "customer currency is wrong"
      assert_equal "wtf", customer.operator_code, "customer operator_code is wrong"
      assert customer.active, "customer should have been active"

      rv2 = rv[1]
      assert_basic_import_attributes rv2, status: 'invalid', error: Importers::AlreadyProcessed, customers: 2
      assert rv2.error.is_a?(Importers::AlreadyProcessed), 'wrong error'
    end

    def test_nondeterministic_results
      # all insert
      create_mock 'file1', 10
      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 1, rv.count, 'expected 1 files to have been processed'
      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 10, updates: 0, customers: 10

      # 2 updates
      Timecop.travel 60
      create_mock 'file1', 12
      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 1, rv.count, 'expected 1 files to have been processed'
      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 2, customers: 12
    end

    # 2 files created in the same minute will trigger a "AlreadyProcessed"
    def test_duplicate_file_matches
      Timecop.freeze

      create_mock 'file1', 12
      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 1, rv.count, 'expected 1 files to have been processed'
      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 12, customers: 12

      create_mock 'file2', 12
      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 1, rv.count, 'expected 1 files to have been processed'
      rv2 = rv[0]
      assert_basic_import_attributes rv2, status: 'invalid', error: Importers::AlreadyProcessed, customers: 12
    end

    # only second file should be loaded, first one should be ignored
    def test_file_order_loading
      create_mock 'file1', 12
      Timecop.travel 60
      create_mock 'file2', 10

      rv = Importers::Pagafasil::StandardBillPaymentBalances.import_balances(mock_file_name('*'), 'wtf')
      assert_equal 2, rv.count, 'expected 2 files to have been processed'

      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 10, customers: 10

      rv2 = rv[1]
      assert_basic_import_attributes rv2, status: 'invalid', error: Importers::AlreadyProcessed, customers: 10
    end



    private

    def create_mock file_name, no_of_customers
      Importers::Pagafasil::StandardBillPaymentBalances.mock_file file_name: mock_file_name(file_name), line_no: no_of_customers
    end

    def assert_basic_import_attributes rv, exp = {}
      log = rv.db_logger.log
      exp_status = exp.delete(:status) || throw('define a status')
      exp_error = exp.delete(:error)

      if exp_status == 'processed'
        exp_inserts = exp.delete(:inserts) || throw('define number of inserts')
        exp_updates = exp.delete(:updates)
      else
        throw('define the error') unless exp_error
        exp_inserts = exp.delete(:inserts) || 0
        exp_updates = exp.delete(:updates) || 0
      end

      exp_customer_count = exp.delete(:customers) || throw('define number of customers')

      assert_equal exp_status, log.status, "status is wrong, error is #{rv.error.try(:class)} #{rv.error.try(:message)}"
      assert_equal 'import', log.direction, 'wrong direction'
      assert_equal 'balances', log.file_type, 'wrong file_type'
      assert_equal 'wtf', log.operator_code, 'wrong operator code'
      assert_equal 'PSBB', log.receiver_id, 'wrong receiver ID'
      assert_equal 'ECNV', log.sender_id, 'wrong sender ID'

      assert log.started_at, 'started_at expected'
      assert log.finished_at, 'finished_at expected'
      assert log.finished_at >= log.started_at, 'finished_at should be after started_at'
      assert log.time_elapsed >= 0, 'expected a meaningful time_elapsed value'
      assert_equal exp_inserts, log.insert_count, 'insert_count is off'
      assert_equal exp_updates, log.update_count, 'update_count is off' if exp_updates

      assert_equal exp_inserts, rv.insert_count, "wrong number of inserts"
      assert_equal exp_updates, rv.update_count, "wrong number of updates" if exp_updates
      assert_equal exp_customer_count, Customer.count, "customer count is wrong"
    end

  end
end