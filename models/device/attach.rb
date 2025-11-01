class AttachDevice < DStruct::DStruct

  attributes  integers:  [:terminal_id]

  def self.call(id, context)

    input = new(context.params)
    admin_id = context.admin_id

    device = Device.where(id: id, terminal_id: nil, status: 'idle').first
    terminal = Terminal.where(id: input.terminal_id, access_token: nil).first

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :device, device
        option :terminal, terminal

        def available?(value)
          terminal && device
        end
      end

      key(:terminal_id) { int? & available? }
    end

    input.add_validation_schema validation_schema

    if input.valid?

      DB.transaction do
        # set new key and token for existing terminal
        terminal.update terminal_key: Utils.generate_random_token[0...10], access_token: device.serial_number
        # update device with audit
        Device.update(device.id, admin_id, terminal_id: terminal.id, assigned_at: Time.now, status: 'assigned')
      end

      # store entry in memcache
      access_code = Utils.random_pin(6)
      otp_code    = 'none' # Admin[admin_id].my_otp_code TODO: remove me
      AddTerminal.store_terminal_init_data_entry_in_cache(access_code, otp_code, terminal, admin_id)

      # print id (treminal id) and terminal_key; no default cashier its already there
      context.render_success({id: terminal.id, api_key: terminal.terminal_key,  # old workflow data
                              access_code: access_code})                        # new workflow data
    else

      # # TODO: remove response for GET, it is used for easier client development
      # if context.request.is_get?
      #   # invalid terminal
      #   context.render_error(['unknown terminal serial/access_token']) unless terminal
      #
      #   # attach device
      #   terminal.update terminal_key: Utils.generate_random_token[0...10], access_token: device.serial_number
      #   device.update terminal_id: terminal.id, assigned_at: Time.now, status: 'assigned'
      #
      #   terminal_access_codes_and_keys_for_test(context, terminal)
      # else
      #   context.render_error(input.errors)
      # end

      context.render_error(input.errors)
    end
  end

  # # TODO: remove this, used for client development
  # def self.terminal_access_codes_and_keys_for_test(context, terminal)
  #
  #   # random codes
  #   access_code = Utils.random_pin(6)
  #   otp_code = Utils.random_pin(6)
  #
  #   AddTerminal.store_terminal_init_data_entry_in_cache(access_code, otp_code, terminal, admin_id)
  #   context.render_success(api_key: terminal.terminal_key, access_code: access_code, otp_code: otp_code) # we output otp_code, chris does not have authenticator
  # end

end
