WebPayAdmin.route('accounts') do |r|
  r.get ':id/show' do |id|
    puts '=> getting account ...'
    account = Account[id]

    if account.type == 'business'
      pos_trxs_ds       = account.transactions_dataset.exclude(terminal_id: nil)
      wallet_trxs_ds    = account.transactions_dataset.where(terminal_id: nil)
      pos_sales_trxs_ds = pos_trxs_ds.where(voided: false).exclude(transaction_type: 'bill_reversal_mpos')

      { account: account,
        wallet_transactions:  { count:        wallet_trxs_ds.count},
        pos_transactions:     { count:        pos_trxs_ds.count,
                                sales_amount: pos_sales_trxs_ds.sum(:amount),
                                sales_count:  pos_sales_trxs_ds.count},

        users: account.users_dataset.select(:id, :first_name, :last_name),
        terminals: account.terminals_dataset.select(:id, :merchant_name, :merchant_address),
        stocks: account.voucher_stocks_dataset.order(:name)}

    # personal or bank account
    else
      trxs_ds  = account.transactions_dataset.where(terminal_id: nil)
      { account: account,
        transactions: { count: trxs_ds.count,
                        debit_count: trxs_ds.where(type: 'debit').count,
                        credit_count: trxs_ds.where(type: 'credit').count,
                        debit_amount: trxs_ds.where(type: 'debit').sum(:amount),
                        credit_amount: trxs_ds.where(type: 'credit').sum(:amount)},
        users: account.users_dataset.select(:id, :first_name, :last_name)}
    end
  end

  r.get ':id/sales-stats' do |id|
    puts '=> getting sales stats ...'
    DB[:transactions].where(account_id: id, voided: false).exclude(terminal_id: nil).
                                        select_group(:transaction_type).
                                        select_append{sum(:amount).as(:total)}.
                                        select_append{count(:id).as(:count)}.order(:transaction_type).all
  end

  r.post ':id/update/:type' do |id, type|
    account = Account[id]
    puts '=> updating account ...'
    if type == 'business'
      UpdateBusinessAccount.call(id, self)
    elsif type == 'personal'
      UpdatePersonalAccount.call(id, self)
    elsif BANK_ACCOUNT_TYPES.keys.stringify.include?(type)
      UpdateBankAccount.call(id, self)
    end
  end

  r.post ':id/update-limits' do |id|
    puts '=> updating limits ...'
    UpdateAccountLimits.call(id, self)
  end

  r.post ':id/adjust-exposure' do |id|
    puts '=> adjusting exposure ...'
    AdjustExposure.call(id, self)
  end

  r.post ':id/add-terminal' do |id|
    puts '=> adding new terminal ...'
    AddTerminal.call(id, self)
  end

  r.get ':id/replenish-stock' do |id|
    puts '=> getting account\'s stocks ...'
    VoucherStock.where(account_id: id).order(:name).all
  end

  r.post ':id/replenish-stock/:id' do |id, vs_id|
    puts '=> replenishing account\'s stock ...'
    ReplenishVoucherStock.call(vs_id, self)
  end

  r.post ':id/approve-bank-account' do |id|
    puts '=> approving bank account ...'
    account = Account.update(id, admin_id, {active: true, state: 'approved'})
    account.public_values
  end

  r.post ':id/remove-bank-account' do |id|
    puts '=> removing bank account ...'
    RemoveBankAccount.call(id, self)
  end

  r.post 'create' do
    puts '=> creating account ...'
    CreateAccount.call(self)
  end

  r.post ':page' do |page|
    puts '=> getting accounts ...'
    r.paginated_dataset(*Account.paginate(page, params[:search])).all
  end
end
