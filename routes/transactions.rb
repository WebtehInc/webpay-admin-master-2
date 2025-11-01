WebPayAdmin.route('transactions') do |r|

  ds = Transaction.reverse(:id).select(*Transaction::PUBLIC_ATTRS)

  r.post ':page/pos' do |page|
    puts '=> getting pos transactions ...'
    r.paginated_dataset(*Transaction.paginate(page, params[:search], ds.exclude(terminal_id: nil))).to_json(include:
      {account: {only: [:account_number, :type]}, terminal: {only: [:merchant_name, :merchant_address, :id]}, cashier: {only: [:full_name]}})
  end

  r.post ':page/personal' do |page|
    puts '=> getting personal transactions ...'
    r.paginated_dataset(*Transaction.paginate(page, params[:search], ds.where(terminal_id: nil).exclude(transaction_type: BANK_TRANSACTION_TYPES.keys.stringify))).to_json(include:
      {account: {only: [:account_number, :type]}, user: {only: [:id, :first_name, :last_name]}})
  end

  r.post ':page/bank' do |page|
    puts '=> getting bank transactions ...'
    r.paginated_dataset(*Transaction.paginate(page, params[:search], ds.where(transaction_type: BANK_TRANSACTION_TYPES.keys.stringify))).to_json(include:
      {account: {only: [:account_number, :type]}, user: {only: [:id, :first_name, :last_name]}})
  end

  r.post ':page/not-registered' do |page|
    puts '=> getting non-registered transactions ...'
    ds = DB[:reversals]
          .join(:transactions,
                amount: :amount,
                transaction_type: :transaction_type,
                services_batch_number: :services_batch_number,
                terminal_id: :terminal_id,
                systan: :systan)
          .select(Sequel[:transactions][:id], Sequel[:reversals][:id].as(:reversal_id), Sequel[:transactions][:terminal_id], Sequel[:transactions][:services_batch_number], Sequel[:transactions][:transaction_type], Sequel[:transactions][:amount], Sequel[:transactions][:currency], Sequel[:transactions][:created_at])
          .where(Sequel[:reversals][:id] => 1..1000000) # this makes it few millis instead seconds !?
          .reverse(Sequel[:reversals][:id])

    count = Philtre.new(params[:search]).apply(ds).count
    filtered_dataset = Philtre.new(params[:search]).apply(ds.limit(Sequel::Model::PER_PAGE).offset(Sequel::Model::PER_PAGE * (page.to_i - 1)))
    r.paginated_dataset(Sequel::Model::PER_PAGE, count, filtered_dataset.all)
  end

  r.post ':page/export' do |page|
    puts '=> exporting transactions ...'

    # regular paginated search
    per_page, count, dataset = Transaction.paginate(page, params[:search], ds)

    # limit export to single page
    fields        = [:id, :terminal_id, :amount, :currency, :transaction_type, :services_batch_number, :customer_number, :operator_code, :voided, :created_at]
    export_limit  = 50000
    per_page      = export_limit
    dataset       = dataset.limit(export_limit).select(*fields)
    count         = dataset.count

    r.paginated_dataset(per_page, count, dataset).all
  end
end
