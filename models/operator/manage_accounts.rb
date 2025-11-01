module OperatorManageAccounts
  def self.call(context)
    api_key = context.request.headers["ApiKey"] || ""
    api_key_hash = Digest::SHA512.hexdigest(api_key)
    operator = Operator.where(api_key_hash: api_key_hash).first

    if operator
      params = context.params
      customers = {}

      # check input fields
      unless number_of_accounts = params[:number_of_accounts]
        context.render_error(error: "number_of_accounts not found")
      end
      unless sum_of_balances = params[:sum_of_balances]
        context.render_error(error: "sum_of_balances not found")
      end
      unless accounts = params[:accounts]
        context.render_error(error: "accounts not found")
      end

      begin
        number_of_accounts = Integer(number_of_accounts)
        sum_of_balances = Integer(sum_of_balances)
      rescue => e
        context.render_error(error: "#{e.class}: #{e.message}")
      end

      # load customers
      calculated_number_of_accounts = 0
      calculated_sum_of_balances = 0
      accounts.each do |account|
        calculated_number_of_accounts += 1
        calculated_sum_of_balances += account[:balance].to_i

        if [true, false].include? account[:active]
          if customer = Customer.where(operator_code: operator.code, number: account[:account].to_s).first
            customers[account[:account]] = customer
          else
            context.render_error(error: "Account #{account[:account]} not found")
          end
        else
          context.render_error(error: "Account #{account[:account]} does not have active value")
        end
      end

      # check totals
      if calculated_number_of_accounts != number_of_accounts
        context.render_error(error: "number_of_accounts does not match, found #{calculated_number_of_accounts}, declared #{number_of_accounts}")
      end
      if calculated_sum_of_balances != sum_of_balances
        context.render_error(error: "sum_of_balances does not match, found #{calculated_sum_of_balances}, declared #{sum_of_balances}")
      end

      # update customers
      accounts.each do |account|
        customers[account[:account]].update(balance: account[:balance], active: account[:active])
      end

      context.render_success(total_updates: customers.keys.size)
    else
      context.render_error({ error: "Operator not found" }, 404)
    end
  end
end
