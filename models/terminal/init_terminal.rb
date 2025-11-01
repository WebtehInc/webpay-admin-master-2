class InitTerminal < DStruct::DStruct

  attributes strings: [:access_code, :otp_code]

  def self.call(context)

    input = new(context.params)

    # access_code, otp_code, terminal_id, terminal_key, tmk, tmk_kcv
    init_data_entry = MemoryStore.get :terminal_init_data_entry

    # set admin from memory entry
    admin_id        = init_data_entry&.dig(:admin_id)
    admin           = Admin[admin_id]

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        option :init_data_entry, init_data_entry
        option :input, input
        option :admin, admin

        def valid_access_code?(value)
          value == init_data_entry&.dig(:access_code)
        end

        # match against calculated otp code from admin record
        def valid_otp_code?(value)
          return false unless admin
          totp = ROTP::TOTP.new(admin.otp_code)
          LOGGER.debug "OTP code: #{totp.now}"
          totp.verify_with_drift(value, 60, Time.now)
        end
      end

      key(:access_code) { filled? & valid_access_code? }
      key(:otp_code)    { filled? & valid_otp_code? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      terminal = Terminal[init_data_entry[:terminal_id]]
      tmk, tmk_kcv = fetch_keys terminal

      context.render_success({terminal_id:  init_data_entry[:terminal_id],
                              terminal_key: init_data_entry[:terminal_key],
                              tmk:          tmk,
                              tmk_kcv:      tmk_kcv})
    else
      context.render_error(input.errors)
    end
  end


  private

  def self.fetch_keys(terminal)
    access_token = terminal.access_token

    api_keys = InfoSwitch.api_keys('Terminal', access_token)
    gw_terminal = InfoSwitch::TerminalApi.new.create_or_update_terminal({
      authenticity_token: api_keys[:__authenticity_token],
      secret: api_keys[:__secret],
      name: "Terminal #{access_token}",
      tid:  access_token,
      mid:  'Terminal',
      attended: true,
      location_indicator: 'merchant',
      load_balancer: 'NullBalancer',
      installment_options: 'NullInstallments',
      generate_tmk: true,
      transport_key: WebPayAdmin.opts[:terminal_transport_key],
      terminal_status: 'active'
    }.merge(InfoSwitch.merchant_keys))

    [ tmk     = gw_terminal['tmk'],
      tmk_kcv = gw_terminal['tmk_kcv'] ]
  end

end
