class UpdateLimit < DStruct::DStruct

  attributes integers: [:amount], booleans: [:active]

  def self.call(id, context)

    input = new(context.params)

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :input, input

        def positive_if_active?(value)
          return true if !input.active
          return true if (input.active && value > 0)
        end
      end

      key(:amount)  { int? & positive_or_zero? & positive_if_active? }
      key(:active)  { bool? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      context.render_success if Limit.update(id, context.admin_id, input.to_h)
    else
      context.render_error(input.errors)
    end
  end

end
