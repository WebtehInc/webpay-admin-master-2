require_relative "../integration_helper"

class ImporterTest < Test

  def setup
    super
    FileUtils.rm_rf files_path
    FileUtils::mkdir_p files_path
    FileUtils.rm_rf "./tmp/test/"
  end


  def teardown
    super
  end


  def freeze_time
    Timecop.freeze Time.parse("September 21, 2010, 15:10:22")
  end

  def reset_sequences
    DB.execute <<-SQL
        alter sequence transactions_id_seq restart;
        alter sequence terminals_id_seq restart;
    SQL
  end

  private

  # be careful when you play with this method, see ImporterTest#teardown
  def files_path
    "/tmp/WebPay-test/#{subpath_of_test}"
  end

  def mock_file_name file_name
    files_path + "/#{file_name}"
  end


  # [20:11:39] Damir Roso: account, terminal, cashier, operator
  # [20:11:43] Damir Roso: Sve po 2
  # [20:12:13] Damir Roso: I izbrojis totale i countove
  # [20:12:35] Damir Roso: 10-tak assertova
  def mock_transactions_for_POS_exports(options = {})
    terminal = Terminal.create
    @op1 = Operator.create(code: 'op1', name: 'Operator 1', type: 'bill', currency: 'ANG')
    @op2 = Operator.create(code: 'op2', name: 'Operator 2', type: 'bill', currency: 'ANG')

    @acc1 = Account.create(type: 'business', title: 'Simple business account 1', account_number: '12345', currency: 'ANG', merchant_name: 'Merchant 1')
    @acc2 = Account.create(type: 'business', title: 'Simple business account 2', account_number: '54321', currency: 'ANG', merchant_name: 'Merchant 2')
    @acc3 = Account.create(type: 'business', title: 'Simple business account 3', account_number: '99999', currency: 'ANG', merchant_name: 'Merchant with no Transactions inc.')

    @term1_1 = Terminal.create(account_id: @acc1.id)
    @cashier1_1_1 = Cashier.create(terminal_id: @term1_1.id, full_name: '@cashier1_1_1', hashed_pin: 'bugavuga')
    @term1_2 = Terminal.create(account_id: @acc1.id)
    @cashier1_2_1 = Cashier.create(terminal_id: @term1_2.id, full_name: '@cashier1_2_1', hashed_pin: 'bugavuga')
    @cashier1_2_2 = Cashier.create(terminal_id: @term1_2.id, full_name: '@cashier1_2_2', hashed_pin: 'bugavuga')
    @term2_1 = Terminal.create(account_id: @acc2.id)
    @cashier2_1_1 = Cashier.create(terminal_id: @term2_1.id, full_name: '@cashier2_1_1', hashed_pin: 'bugavuga')

    mock_payment = {terminal_id: terminal.id, type: "credit", amount:10_00, currency: "USD", transaction_type: "bill_mpos",          status: "approved", operator_code: "ch", balance:0, customer_number: SecureRandom.base64}
    mock_refund  = {terminal_id: terminal.id, type: "debit",  amount:10_00, currency: "USD", transaction_type: "bill_reversal_mpos", status: "approved", operator_code: "ch", balance:0, customer_number: SecureRandom.base64}
    lodge_last = Proc.new do
      t = Transaction.last
      ServicesLodgment.create(
        currency: 'ANG', started_at: t.created_at,
        account_id: t.account_id, terminal_id: t.terminal_id, cashier_id: t.cashier_id, batch_number: t.services_batch_number
      )
    end

    Transaction.create mock_payment.merge(account_id: @acc1.id, terminal_id: @term1_1.id, cashier_id: @cashier1_1_1.id, amount: 10_00, operator_code: 'op1', customer_number: '123456789', services_batch_number: 1)
    Transaction.create mock_refund.merge(account_id: @acc1.id, terminal_id: @term1_1.id, cashier_id: @cashier1_1_1.id, amount: 20_00, operator_code: 'op2', customer_number: '4798347974', services_batch_number: 1)
    Transaction.create mock_refund.merge(account_id: @acc1.id, terminal_id: @term1_1.id, cashier_id: @cashier1_1_1.id, amount: 20_00, operator_code: 'op2', customer_number: '4798347974', services_batch_number: 1)
    Transaction.create mock_refund.merge(account_id: @acc1.id, terminal_id: @term1_1.id, cashier_id: @cashier1_1_1.id, amount: 30_00, operator_code: 'op1', status: 'declined', customer_number: '3289723972397', services_batch_number: 1)
    lodge_last[]

    Transaction.create mock_payment.merge(account_id: @acc1.id, terminal_id: @term1_2.id, cashier_id: @cashier1_2_1.id, amount: 20_00, operator_code: 'op2', customer_number: '098765432', services_batch_number: 1)
    lodge_last[]

    Transaction.create mock_payment.merge(account_id: @acc1.id, terminal_id: @term1_2.id, cashier_id: @cashier1_2_2.id, amount: 30_00, operator_code: 'op1', customer_number: '321457546', services_batch_number: 2)
    lodge_last[]

    Transaction.create mock_payment.merge(account_id: @acc1.id, terminal_id: @term1_2.id, cashier_id: @cashier1_2_2.id, amount: 35_00, operator_code: 'op2', customer_number: '321457546', services_batch_number: 3)
    lodge_last[]

    Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 40_00, operator_code: 'op2', customer_number: '378372972', services_batch_number: 4)
    Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 50_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 4)
    Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 60_00, operator_code: 'op1', status: 'declined', customer_number: '34897349734', services_batch_number: 4)
    Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 50_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 4, voided: true)
    Transaction.create mock_refund.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 10_00, operator_code: 'op1', customer_number: '3487397239', services_batch_number: 4)
    lodge_last[]

    if options[:add_quickbooks_report_trxs]
      # does the report split away
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 50_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 5)
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 30_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 5)
      lodge_last[]

      # prepaid_mpos
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 20_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 6, transaction_type: 'prepaid_mpos')
      lodge_last[]

      # mappings to funny operator names
      o = Operator.create(code: 'en', name: 'Entiero Na Kuota',  type: 'bill', currency: 'ANG')
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 20_00, operator_code: o.code, customer_number: '483734879', services_batch_number: 7, transaction_type: 'prepaid_mpos')
      o = Operator.create(code: 'pb', name: 'Paga Bo But',       type: 'bill', currency: 'ANG')
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 20_00, operator_code: o.code, customer_number: '483734879', services_batch_number: 7, transaction_type: 'prepaid_mpos')
      o = Operator.create(code: 'dp', name: 'DigiCell Postpaid', type: 'bill', currency: 'ANG')
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 20_00, operator_code: o.code, customer_number: '483734879', services_batch_number: 7, transaction_type: 'prepaid_mpos')
      lodge_last[]

      # one unlodged trx that should not be present!
      Transaction.create mock_payment.merge(account_id: @acc2.id, terminal_id: @term2_1.id, cashier_id: @cashier2_1_1.id, amount: 20_00, operator_code: 'op2', customer_number: '483734879', services_batch_number: 8, transaction_type: 'prepaid_mpos')
    end
  end

  def assert_basic_export_attributes rv, exp_file_path, exp = {}
    log = rv.db_logger.log

    exp_status   = exp.delete(:status) || throw('define a status')
    exp_operator = exp.delete(:operator) || throw('define an operator')
    exp_file_type = exp.delete(:file_type) || throw('define a file_type for export (payment/refund)')
    exp_company_id = exp.delete(:company_id) || throw('define a company_id')
    exp_file_reference = exp.delete(:file_reference) || throw('define a file_reference number')
    exp_file_mask = exp.delete(:file_mask)

    exp_error = exp.delete(:error)

    if exp_status == 'processed'
      exp_trxs = exp.delete(:trxs) || throw('define number of transactions exported')
      exp_balance = exp.delete(:balance) || throw('define exported trx balance')
    else
      throw('define the error') unless exp_error
    end

    assert_equal exp_status, log.status, "status is wrong, error is #{rv.error.try(:class)} #{rv.error.try(:message)}"
    assert_equal 'export', log.direction, 'wrong direction'
    assert_equal exp_file_type, log.file_type, 'wrong file_type'
    assert_equal exp_operator.code, log.operator_code, 'wrong operator code'
    assert_equal exp_operator.file_exchange_institution_id, log.receiver_id, 'wrong receiver ID'
    assert_equal 'PSBB', log.sender_id, 'wrong sender ID'

    assert_equal exp_trxs, rv.trx_count, "wrong number of transactions" if exp_trxs
    assert_equal exp_balance, rv.trx_balance, "wrong transaction balance" if exp_balance

    assert_equal exp_trxs, log.trx_count, "wrong number of transactions" if exp_trxs
    assert_equal exp_balance, log.trx_sum_amount, "wrong transaction balance" if exp_balance

    assert_equal exp_company_id, log.company_id, "wrong company_id"
    assert_equal exp_file_reference, log.file_reference_number, "wrong file_reference_number"

    if exp_file_mask
      assert log.file_path =~ exp_file_mask, "file mask #{exp_file_mask} is off on file #{log.file_path}"
    end

    assert log.started_at, 'started_at expected'
    assert log.finished_at, 'finished_at expected'
    assert log.finished_at >= log.started_at, 'finished_at should be after started_at'
    assert log.time_elapsed >= 0, 'expected a meaningful time_elapsed value'

    if exp_trxs
      if exp_trxs > 1
        assert log.trx_min_id < log.trx_max_id, "something is off with trx ids in the log, got #{log.trx_min_id} < #{log.trx_max_id}"
      elsif exp_trxs == 1
        assert log.trx_min_id == log.trx_max_id, "something is off with trx ids in the log, got #{log.trx_min_id} == #{log.trx_max_id}"
        # else it's all null
      end

      assert_equal exp_trxs, DB.fetch(rv.scope).count, 'number of trxs covered in the sql scope is off'
      if exp_trxs > 0
        trxs = DB.fetch(rv.scope).all.sort{|t1, t2| t1[:id] <=> t2[:id] }
        assert_equal trxs.first[:id], log.trx_min_id, 'trx_min_id is off'
        assert_equal trxs.last[:id],  log.trx_max_id, 'trx_max_id is off'
      end
    end

    if exp_status == 'processed'
      assert_equal_files exp_file_path, log.file_path
    end
  end

end