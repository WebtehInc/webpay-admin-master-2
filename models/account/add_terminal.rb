class AddTerminal < DStruct::DStruct

  attributes  strings:  [ :merchant_name, :merchant_address, :merchant_phone, :merchant_email, :merchant_fax,
                          :merchant_contact, :receipt_text, :cashiers_full_name, :access_token,
                          :opening_hours, :opening_minutes, :closing_hours, :closing_minutes],
              booleans: [ :active]

  def self.call(id, context)

    add_terminal = new(context.params)
    admin_id = context.admin_id

    account = Account[id]
    device = Device.where(serial_number: add_terminal.access_token, terminal_id: nil, status: 'idle').first

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :device, device

        def unique?(value)
          !Terminal.where(access_token: value).first
        end

        def available?(value)
          device
        end
      end

      key(:merchant_name)         { filled? & size?(3..60) }
      key(:merchant_address)      { filled? & size?(3..80) }
      key(:merchant_phone)        { filled? & numeric? & size?(7..15) }
      key(:merchant_contact)      { filled? & size?(3..40) }
      key(:merchant_fax)          { empty? | (numeric? & size?(7..15)) }
      key(:merchant_email)        { filled? & email? & size?(5..40) }

      key(:cashiers_full_name)    { filled? & size?(10..100) }
      key(:access_token)          { filled? & size?(8..16) & unique? & available?}

      key(:opening_hours)         { filled? & int? & gteq?(0) & lteq?(23) }
      key(:opening_minutes)       { filled? & int? & gteq?(0) & lteq?(59) }
      key(:closing_hours)         { filled? & int? & gteq?(0) & lteq?(23) }
      key(:closing_minutes)       { filled? & int? & gteq?(0) & lteq?(59) }

      key(:active)                { bool? }
      key(:receipt_text)          { empty? | size?(10..200) }
    end

    add_terminal.add_validation_schema validation_schema

    if add_terminal.valid?

      DB.transaction do
        @terminal = Terminal.create_with_audit(admin_id, add_terminal.to_h.except(:cashiers_full_name).merge(
                            account_id: id,
                            default_currency: account.currency,
                            accepted_currencies: [account.currency],
                            accepted_cards: ACCEPTED_CARDS.keys.stringify,
                            # access_token: Utils.generate_random_token,
                            terminal_key: Utils.generate_random_token[0...10]))

        Device.update(device.id, admin_id, terminal_id: @terminal.id, assigned_at: Time.now, status: 'assigned')

        # create default cashier manager
        @random_pin = Utils.random_pin(4)
        Cashier.create( terminal_id: @terminal.id,
                        full_name: add_terminal.cashiers_full_name,
                        hashed_pin: Digest::SHA512.hexdigest(@random_pin),
                        manager: 'true')
      end

      # store entry in memcache
      access_code = Utils.random_pin(6)
      otp_code    = 'none' #Admin[admin_id].my_otp_code TODO: remove me
      store_terminal_init_data_entry_in_cache(access_code, otp_code, @terminal, admin_id)

      # render output
      # we dont print access_token, we use device serial printed on sticker instead
      context.render_success({id: @terminal.id, cashier_pin: @random_pin, api_key: @terminal.terminal_key,  # old workflow data
                              access_code: access_code })                                                   # new workflow data
    else
      context.render_error(add_terminal.errors)
    end
  end

  def self.store_terminal_init_data_entry_in_cache(access_code, otp_code, terminal, admin_id) # TODO: remove otp_code arg
    tmk, tmk_kcv = fetch_keys(terminal.access_token)
    MemoryStore.set(:terminal_init_data_entry, {  # old workflow
                                                  terminal_id:  terminal.id,
                                                  terminal_key: terminal.terminal_key,

                                                  # new workflow
                                                  access_code:  access_code,
                                                  # otp_code:     otp_code,
                                                  admin_id:     admin_id,
                                                  tmk:          tmk,
                                                  tmk_kcv:      tmk_kcv}, WebPayAdmin.opts[:access_code_ttl])
  end

  def self.fetch_keys(access_token)
    # TODO: fetch keys from crypto service
    [ tmk     = 'set_tmk_key_here',
      tmk_kcv = 'set_tmk_key_kcv_here']
  end

end
