class UpdateOperator < DStruct::DStruct
  attributes strings: [:info, :file_exchange_company_id, :file_exchange_institution_id], booleans: [:active], integers: [:min_amount], arrays: [:email]

  def self.call(id, context)
    input = new(context.params)

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join("../errors.yml")
      end

      key(:info) { empty? | size?(3..200) }
      key(:active) { bool? }
      key(:min_amount) { int? }
      # key(:email)     { filled? } # validate array elements ?
    end

    input.add_validation_schema validation_schema

    if input.valid?
      context.render_success if Operator.update(id, context.admin_id, input.to_h)
    else
      context.render_error(input.errors)
    end
  end
end

class UpdateOperator::GenerateApiKey
  def self.call(id, context)
    api_key = SecureRandom.base64(30)
    api_key_hash = Digest::SHA512.hexdigest(api_key)

    # update
    operator = Operator.update(id, context.admin_id, api_key_hash: api_key_hash)

    # render
    context.render_success(api_key: api_key, operator: operator.name)
  end
end
