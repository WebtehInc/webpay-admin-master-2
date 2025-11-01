class ReplenishVoucherStock < DStruct::DStruct
  attributes integers: [:quantity]#, strings: [:notify_quantity]

  def self.call(stock_id, context)

    replenish = new(context.params)

    # models
    stock = VoucherStock[stock_id]

    validation_schema = Dry::Validation.Form do
      configure do
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :stock, stock

        def valid_stock?(value)
          stock
        end
      end

      key(:quantity)  { int? & valid_stock?}
      # key(:notify_quantity) { empty? | (int? & lt?(100)) }
    end

    replenish.add_validation_schema validation_schema

    if replenish.valid?
      stock.lock!

      new_quantity = stock.quantity + replenish.quantity

      VoucherStock.update(stock_id, context.admin_id, quantity: new_quantity, last_purchase_quantity: replenish.quantity, last_purchase_at: Time.now)
      context.render_success
    else
      context.render_error(replenish.errors)
    end
  end
end
