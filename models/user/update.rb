class UpdateUser < DStruct::DStruct

  attributes strings: [:password, :address, :city, :zip, :country, :phone, :type], booleans: [:active]

  def self.call(id, context)

    update_profile = new(context.params)
    update_profile.add_validation_schema MyValidationSchema

    if update_profile.valid?
      context.render_success if User.update(id, context.admin_id, update_profile.to_h)
    else
      context.render_error(update_profile.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end

    key(:address)       { filled? & size?(2..40) }
    key(:city)          { filled? & alpha? & size?(2..20) }
    key(:zip)           { empty? | size?(4..10) }
    key(:country)       { filled? & inclusion?(COUNTRY_CODES) }
    key(:phone)         { filled? & numeric? & size?(8..15) }
    key(:active)        { bool? }
    key(:type)          { filled? & inclusion?(USER_TYPES.keys.stringify) }
  end
end