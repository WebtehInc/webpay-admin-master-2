class ConfigureNFCWriter < DStruct::DStruct

  attributes strings: [:access_token, :systan, :digest]

  def self.call(context)

    input = new(context.params)


    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        option :input, input

        def valid_digest?(value)
           value == Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + input.access_token.to_s + input.systan.to_s)
        end
      end

      key(:access_token)  { filled? & inclusion?(WebPayAdmin.opts[:nfc_writer_access_tokens]) }
      key(:systan)        { filled? }
      key(:digest)        { filled? & valid_digest? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      data_key, data_key_kcv = self.fetch_keys(input.access_token)
      digest =  Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + data_key.to_s + data_key_kcv.to_s)

      context.render_success( data_key: data_key,
                              data_key_kcv: data_key_kcv,
                              digest: digest)
    else
      context.render_error(input.errors)
    end
  end

  def self.fetch_keys(access_token)
    terminal_session_keys = InfoSwitch::PosApi.new.configure_terminal(NFCWriter.api_keys(access_token))
    [ data_key      = terminal_session_keys['data_key'],
      data_key_kcv  = terminal_session_keys['data_key_kcv']]
  end

end
