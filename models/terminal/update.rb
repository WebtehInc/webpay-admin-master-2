class UpdateTerminal < DStruct::DStruct

  attributes  strings:  [ :merchant_name, :merchant_address, :merchant_phone, :merchant_fax, :merchant_email, :merchant_contact,
                          :receipt_text, :opening_hours, :opening_minutes, :closing_hours, :closing_minutes],
              booleans: [:active]

  def self.call(id, context)

    update_terminal = new(context.params.except(:id))
    update_terminal.add_validation_schema MyValidationSchema
    terminal = Terminal[id] # fetch this for clean increment for audit, it is <#SqlExpression ... otherwise

    if update_terminal.valid?
      context.render_success if Terminal.update(id, context.admin_id,
                                                update_terminal.to_h.merge(config_version: terminal.config_version + 1))
    else
      context.render_error(update_terminal.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end

    key(:merchant_name)         { filled? & size?(3..60) }
    key(:merchant_address)      { filled? & size?(3..80) }
    key(:merchant_phone)        { filled? & (numeric? & size?(8..15)) }
    key(:merchant_contact)      { filled? & size?(3..40) }
    key(:merchant_fax)          { empty? | (numeric? & size?(7..15)) }
    key(:merchant_email)        { filled? & (email? & size?(5..40)) }

    key(:opening_hours)         { filled? & int? & gteq?(0) & lteq?(23) }
    key(:opening_minutes)       { filled? & int? & gteq?(0) & lteq?(59) }
    key(:closing_hours)         { filled? & int? & gteq?(0) & lteq?(23) }
    key(:closing_minutes)       { filled? & int? & gteq?(0) & lteq?(59) }

    key(:receipt_text)          { filled? & size?(10..200) }
    key(:active)                { bool? }

  end

end