class PrepareNFCWriterInitData < DStruct::DStruct

  attributes integers: [:writer_id]

  def self.call(context)

    input         = new(context.params)
    admin_id      = context.admin_id
    admin         = Admin[admin_id]

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
      end

      key(:writer_id)  { int? & inclusion?((0...WebPayAdmin.opts[:nfc_writer_access_tokens].size).to_a) } # array of writers ids - [0,1,2 ...]
    end

    input.add_validation_schema validation_schema

    if input.valid?
      access_code = Utils.random_pin(6)
      otp_code = admin.my_otp_code
      store_nfc_writer_init_data_entry_in_cache(access_code, otp_code, input, admin_id)
      context.render_success(access_code: access_code)
    else
      context.render_error(input.errors)
    end
  end

  def self.store_nfc_writer_init_data_entry_in_cache(access_code, otp_code, input, admin_id)
    MemoryStore.set(:nfc_writer_init_data_entry, {access_code: access_code,
                                                  # otp_code: otp_code,
                                                  admin_id: admin_id,
                                                  access_token: WebPayAdmin.opts[:nfc_writer_access_tokens][input.writer_id]}, WebPayAdmin.opts[:access_code_ttl])
  end
end
