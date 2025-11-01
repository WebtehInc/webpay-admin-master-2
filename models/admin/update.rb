class UpdateAdmin < DStruct::DStruct

  attributes strings: [:email, :phone], booleans: [:active, :superuser]

  def self.call(id, context)

    update_profile = new(context.params)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
      end

      key(:phone)         { filled? & numeric? & size?(8..15) }
      key(:email)         { filled? & email? }
      key(:active)        { bool? }
      key(:superuser)     { bool? }
    end

    update_profile.add_validation_schema validation_schema

    if update_profile.valid?
      context.render_success if Admin.update(id, context.admin_id, update_profile.to_h)
    else
      context.render_error(update_profile.errors)
    end
  end
end