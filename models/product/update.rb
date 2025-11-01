class UpdateProduct < DStruct::DStruct

  attributes strings: [:info], integers: [:notify_quantity]

  def self.call(id, context)

    update_product = new(context.params)
    update_product.add_validation_schema MyValidationSchema

    if update_product.valid?
      context.render_success if Product.update(id, context.admin_id, update_product.to_h)
    else
      context.render_error(update_product.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:info) { empty? | size?(3..40) }
    key(:notify_quantity){ int? & gt?(1) }
  end

end