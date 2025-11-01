WebPayAdmin.route('services-lodgments') do |r|
  r.post ':id/show' do |id|
    puts '=> getting services lodgment ...'
    trxs_ds = DB[:transactions].where(services_batch_number: params[:services_batch_number], terminal_id: params[:terminal_id])

    bill_reversal_trxs =  trxs_ds.where(voided: true,
                                      operator_code: Operator.where(type: 'bill').select_hash(:code, :name).keys).
                                      group_and_count(:operator_code).
                                      select_append{sum(:amount).as(:amount)}

    bill_trxs = trxs_ds.where(# voided: false,
                      operator_code: Operator.where(type: 'bill').select_hash(:code, :name).keys).
                      exclude(transaction_type: 'bill_reversal_mpos').
                      group_and_count(:operator_code).
                      select_append{sum(:amount).as(:amount)}

    # voucher_trxs = trxs_ds.where(voided: false,
    #                   operator_code: Operator.where(type: 'voucher').select_hash(:code, :name).keys).
    #                   group_and_count(:name).select_append{sum(:amount).as(:amount)}.reverse(:amount)

    voucher_trxs = DB[:vouchers___v].join(:transactions___t, voucher_id: :id).where(
                              t__services_batch_number: params[:services_batch_number],
                              t__terminal_id: params[:terminal_id], t__voided: false).
                              select_group(:v__name).
                              select_append{sum(:t__amount).as(:amount)}.
                              select_append{count(:t__id).as(:count)}.order(:v__name)

    topup_trxs    = trxs_ds.where(transaction_type: 'top_up_mpos')
    prepaid_trxs  = trxs_ds.where(transaction_type: 'prepaid_mpos')

    service_trxs_group_per_attr_with_excluded_types = Proc.new do |service, grouping_attr, excluded_types, join, order|
      ds = DB[:transactions___t]
      ds = ds.join(join[:relation], join[:attrs]) if join
      order = order ? order : grouping_attr
      ds.where( t__services_batch_number: params[:services_batch_number],
                t__terminal_id: params[:terminal_id], # voided: false,
                t__operator_code: Operator.where(type: service).select_hash(:code, :name).keys).
                exclude(excluded_types).
                select_group(grouping_attr).
                select_append{sum(:t__amount).as(:amount)}.
                select_append{count(:t__id).as(:count)}.order(order)
    end

    { bill_trxs: bill_trxs.all,
      bill_reversal_trxs: bill_reversal_trxs.all,
      voucher_trxs: voucher_trxs.all,
      topup_trxs: {amount: topup_trxs.sum(:amount), count: topup_trxs.count},
      prepaid_trxs: {amount: prepaid_trxs.sum(:amount), count: prepaid_trxs.count},

      bills_per_payment_method: service_trxs_group_per_attr_with_excluded_types.call(
        'bill',
        :t__payment_method,
        {t__transaction_type: 'bill_reversal_mpos'}).all,

      bills_per_payment_method_type: service_trxs_group_per_attr_with_excluded_types.call(
        'bill',
        :t__payment_method_type,
        {t__transaction_type: 'bill_reversal_mpos'}).all,

      bills_per_cashier: service_trxs_group_per_attr_with_excluded_types.call(
        'bill',
        :c__full_name,
        {t__transaction_type: 'bill_reversal_mpos'},
        {relation: :cashiers___c, attrs: {id: :cashier_id}},
        :c__full_name
        ).all
    }
  end
  r.post ':page' do |page|
    puts '=> getting services lodgments ...'
    r.paginated_dataset(*ServicesLodgment.paginate(page, params[:search])).to_json(include:
    { terminal: {only: [:id, :merchant_name]},
      account: {only: [:account_number, :credit_limit, :merchant_name]},
      cashier: {only: [:full_name]}})
  end
end
