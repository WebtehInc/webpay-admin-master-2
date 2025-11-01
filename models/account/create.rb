class CreateAccount < DStruct::DStruct
  attributes strings: [:merchant_name, :merchant_address, :merchant_phone, :merchant_email, :merchant_fax,
                       :merchant_contact, :merchant_description, :user_id],
             booleans: [:active, :sell_vouchers, :sell_prepaids, :bill_payments, :card_authorization, :top_up, :sale_wallet, :service_curgas, :service_pagatinu]

  def self.call(context)
    context.params[:sale_wallet] = false unless context.params[:sale_wallet] # TODO: remove me after client fix

    create_account = new(context.params)

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
      end

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

    create_account.add_validation_schema validation_schema

    if create_account.valid?
      title = "#{create_account.merchant_name} business account"

      DB.transaction do
        @account = Account.create_with_audit(context.admin_id, create_account.to_h.
          except(:user_id).
          merge(title: title,
                type: "business",
                account_number: Account.generate_account_number,
                currency: WebPayAdmin.opts[:default_curency],
                settings: ACCOUNT_SETTINGS))

        # link user
        if user = User[create_account.user_id.to_i] # optional user_id key hack
          user.add_account @account
        end

        # init stock
        Product.all.each do |p|
          @account.add_voucher_stock name: p.name, operator_code: p.operator_code, product_id: p.id,
                                     active: true, notify_quantity: 0, quantity: 0
        end
      end

      context.render_success @account.values
    else
      context.render_error(create_account.errors)
    end
  end
end
