require_relative 'import_vouchers'

class UploadVouchers < DStruct::DStruct

  attributes strings: [:data, :file_name, :size]

  def self.call(code, context)

    input = new(context.params)

    # models
    operator = Operator[code]

    validation_schema = Dry::Validation.Form do
      configure do
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :operator, operator
        option :file_name, input.file_name

        def valid_product?(value)
          operator && file_name.downcase.include?(operator.name.downcase)
        end
      end

      key(:data)          { filled? & valid_product?}
      key(:file_name)     { filled? }
      key(:size)          { filled? }

    end

    input.add_validation_schema validation_schema

    if input.valid?
      import_result = Importers::ImportVouchers.call(context, operator, input.to_h)

      if !import_result[:error]
        context.render_success import_result
      else
        context.render_error({data: [import_result[:error]]})
      end
    else
      context.render_error(input.errors)
    end
  end

end
