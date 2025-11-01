class CreateCustomer < DStruct::DStruct

  attributes  strings: [:number, :operator_code], integers: [:balance]

  def self.call(context)

    input = new(context.params)
    operator = Operator.where(code: input.operator_code, type: 'bill').first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :operator, operator

        def valid_operator?(value)
          operator
        end

        def unique?(value)
          !Customer.first(operator_code: operator&.code, number: value)
        end
      end

      key(:number)        { filled? & size?(4..60) & unique? }
      key(:operator_code) { filled? & valid_operator? }
      key(:balance)       { int? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      Customer.create_with_audit(context.admin_id,  operator_code: operator.code,
                                                    number: input.number,
                                                    balance: input.balance,
                                                    active: true,
                                                    currency: operator.currency)
      context.render_success
    else
      context.render_error(input.errors)
    end
  end
end
