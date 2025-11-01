require_relative "importer_helper"

module PagafasilImporters
  class TestTdsBalances < ImporterTest

    def setup
      super
      @operator = Operator.create(:code=>"td", :name=>"UTS", :type=>"bill", :active=>true, :currency=>"TBD", :info=>nil, :file_exchange_company_id=>nil, :file_exchange_institution_id=>"ECNV", :file_exchange_reference_number=>nil, :bank_account_number=>nil)
    end

    def test_deterministic_import_result
      create_mock 'file1', nil
      create_mock 'file2', nil

      assert_equal 0, Customer.count, 'expected blank db'
      rv = Importers::Pagafasil::TdsBalances.import_balances(mock_file_name('*'), 'td')
      assert_equal 2, rv.count, 'expected 2 files to have been processed'

      rv1 = rv[0]
      assert_basic_import_attributes rv1, status: 'processed', inserts: 12, updates: 0, customers: 12

      customer = Customer.order(:id).first
      assert_equal 7420, customer.balance, "customer balance is wrong"
      assert_equal "TBD", customer.currency, "customer currency is wrong"
      assert_equal "td", customer.operator_code, "customer operator_code is wrong"
      assert customer.active, "customer should have been active"

      # unfortunately, TDS has no chance of file age/order validation
      rv2 = rv[1]
      assert_basic_import_attributes rv2, status: 'processed', inserts: 0, updates: 0, customers: 12
    end

    # unfortunately, TDS has no chance of file age/order validation
    def test_nondeterministic_results
    end

    # unfortunately, TDS has no chance of file age/order validation
    # 2 files created in the same minute will trigger a "AlreadyProcessed"
    def test_duplicate_file_matches
    end

    # unfortunately, TDS has no chance of file age/order validation
    # only second file should be loaded, first one should be ignored
    def test_file_order_loading
    end



    private

    def create_mock file_name, no_of_customers
      Importers::Pagafasil::TdsBalances.mock_file file_name: mock_file_name(file_name), line_no: no_of_customers
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
      assert_equal 'td', log.operator_code, 'wrong operator code'
      assert_equal nil, log.receiver_id, 'wrong receiver ID'
      assert_equal nil, log.sender_id,   'wrong sender ID'

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