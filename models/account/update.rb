class UpdateAccountLimits < DStruct::DStruct
  attributes integers: [:min_amount, :max_amount, :credit_limit]

  def self.call(id, context)
    update_account = new(context.params)

    validation_schema = Dry::Validation.Form do
      key(:credit_limit) { int? }
      key(:min_amount) { int? }
      key(:max_amount) { int? }
    end

    update_account.add_validation_schema validation_schema

    if update_account.valid?
      account = Account.update(id, context.admin_id, update_account.to_h)
      context.render_success account.values
    else
      context.render_error(update_account.errors)
    end
  end
end

class AdjustExposure < DStruct::DStruct
  attributes integers: [:exposure_amount]

  def self.call(id, context)
    input = new(context.params)

    validation_schema = Dry::Validation.Form do
      key(:exposure_amount) { int? } # new exposure_amount is sent from client (current - deposit amount)
    end

    input.add_validation_schema validation_schema

    account = Account[id]
    new_exposure_amount = input.exposure_amount
    previous_exposure_amount = account.exposure_amount                         # current will become previous
    last_exposure_amount_deposit = previous_exposure_amount - new_exposure_amount  # previous - submitted

    if input.valid?
      account = Account.update(id, context.admin_id, exposure_amount: new_exposure_amount,
                                                     previous_exposure_amount: previous_exposure_amount,
                                                     last_exposure_amount_deposit: last_exposure_amount_deposit)
      context.render_success account.values
    else
      context.render_error(input.errors)
    end
  end
end

class UpdateBusinessAccount < DStruct::DStruct
  attributes strings: [:title, :merchant_name, :merchant_address, :merchant_phone, :merchant_email, :merchant_fax,
                       :merchant_contact, :merchant_description, :user_id],
             booleans: [:active, :sell_vouchers, :sell_prepaids, :bill_payments, :card_authorization, :top_up, :sale_wallet, :service_curgas, :service_pagatinu]

  def self.call(id, context)
    update_account = new(context.params)

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
      end

      key(:title) { filled? & size?(3..100) }
      # key(:type)    { filled? & inclusion?(ACCOUNT_TYPES.keys.stringify) }

      key(:merchant_name) { filled? & size?(3..60) }
      key(:merchant_address) { filled? & size?(3..80) }
      key(:merchant_phone) { filled? & numeric? & size?(7..15) }
      key(:merchant_contact) { filled? & size?(3..40) }

      key(:merchant_fax) { empty? | (numeric? & size?(7..15)) }
      key(:merchant_email) { filled? & email? & size?(5..40) }
      key(:merchant_description) { filled? & size?(3..40) }

      key(:active) { bool? }
      key(:sell_vouchers) { bool? }
      key(:sell_prepaids) { bool? }
      key(:bill_payments) { bool? }
      key(:top_up) { bool? }
      key(:sale_wallet) { bool? }
      key(:card_authorization) { bool? }
      key(:service_curgas) { bool? }
      key(:service_pagatinu) { bool? }

      # optional
      key(:user_id) { empty? | numeric? }
    end

    update_account.add_validation_schema validation_schema

    if update_account.valid?
      account = Account.update(id, context.admin_id, update_account.to_h.except(:user_id))

      # link user
      if account.users.empty? and (user = User[update_account.user_id.to_i]) # optional key hack
        user.add_account account
      end

      context.render_success account.values
    else
      context.render_error(update_account.errors)
    end
  end
end

class UpdatePersonalAccount < DStruct::DStruct
  attributes booleans: [:active] #,strings:  [ :title, :type]

  def self.call(id, context)
    update_account = new(context.params)

    validation_schema = Dry::Validation.Form do
      # key(:title)   { filled? & size?(3..100) }
      # key(:type)    { filled? & inclusion?(ACCOUNT_TYPES.keys.stringify) }

      key(:active) { bool? }
    end

    update_account.add_validation_schema validation_schema

    if update_account.valid?
      account = Account.update(id, context.admin_id, update_account.to_h)
      context.render_success account.values
    else
      context.render_error(update_account.errors)
    end
  end
end

# same as for personal
class UpdateBankAccount < UpdatePersonalAccount
end
