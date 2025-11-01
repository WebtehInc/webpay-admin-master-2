class DownloadCardData < DStruct::DStruct

  CARD_TTL = 5 * 60 # 5 min

  attributes strings: [:access_code, :otp_code, :card_serial_number, :access_token, :digest]

  def self.call(context)

    input = new(context.params)

    # attrs in memory: access_code, type, bin, user_id, admin_id
    card_data_entry_key = "card_data_entry_#{input.access_code}"
    card_data_entry     = MemoryStore.get card_data_entry_key

    # set admin from memory entry
    admin_id        = card_data_entry&.dig(:admin_id)
    admin           = Admin[admin_id]

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        option :card_data_entry, card_data_entry
        option :input, input
        option :admin, admin

        def valid_access_code?(value)
          value == card_data_entry&.dig(:access_code)
        end

        # match against calculated otp code from admin record
        def valid_otp_code?(value)
          return false unless admin
          totp = ROTP::TOTP.new(admin.otp_code)
          LOGGER.debug "OTP code: #{totp.now}"
          totp.verify_with_drift(value, 60, Time.now)
        end

        # check if the card is already saved and older than CARD_TTL
        def unique?(value)
          existing_card = Card.where(serial_number: value).first
          return true unless existing_card
          if existing_card && Time.now - existing_card.created_at < CARD_TTL
            return true   # card record is fresh
          else
            return false  # card record is too old
          end
        end

        def valid_digest?(value)
          value == Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + input.access_code.to_s + input.otp_code.to_s)
        end
      end

      key(:access_code)         { filled? & valid_access_code? }
      key(:otp_code)            { filled? & valid_otp_code? }
      key(:card_serial_number)  { filled? & unique? }
      key(:access_token)        { filled? }
      key(:digest)              { filled? & valid_digest? }
    end

    input.add_validation_schema validation_schema

    if input.valid?

      # re-render cached output from memory if any for duplicate submits
      context.render_success card_data_entry[:cached_response] if card_data_entry[:cached_response]

      access_token = input.access_token

      # get keys and challenge
      card_master_key, card_master_key_kcv, card_master_key_pos = fetch_keys_with_challenge(access_token)

      user  = User[card_data_entry[:user_id]]
      pan   = Luhnacy.generate(16, :prefix => card_data_entry[:bin].to_s)
      private_data = {
              pan:        pan,
              exp_month:  Time.now.month,
              exp_year:   Time.now.year + 1,
              first_name: Utils.translit(user.first_name),
              last_name:  Utils.translit(user.last_name)}
      public_data = {serial_number: input.card_serial_number}

      digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + private_data.values.join)

      DB.transaction do
        # TODO: encrypt pan from merged private_data
        card = Card.create(
                              { type:           card_data_entry[:type],
                                bin:            card_data_entry[:bin],
                                masked_pan:     Card.mask_pan(pan),
                                hashed_pan:     Digest::SHA512.hexdigest(pan),
                                user_id:        card_data_entry[:user_id],
                                serial_number:  public_data[:serial_number],
                                cmk:            card_master_key,
                                cmk_kcv:        card_master_key_kcv,
                              }.merge(private_data))

        card.add_audit_message(admin_id, "Card issued for client ##{user.id}")
      end

      output = {card_data: {public: public_data, private: private_data},
                card_master_key:          card_master_key_pos,
                card_master_key_kcv:      card_master_key_kcv,
                digest:                   digest}

      # save output to memory cache entry before render for duplicate submits
      MemoryStore.set(card_data_entry_key, card_data_entry.merge(cached_response: output), WebPayAdmin.opts[:access_code_ttl])
      context.render_success output
    else
      context.render_error(input.errors)
    end
  end

  def self.fetch_keys_with_challenge(access_token)
    # master key for a new card
    m_master_key = InfoSwitch::MifareApi.new.generate_master_key(NFCWriter.api_keys(access_token))

    [ card_master_key         = m_master_key['cmk_host'],
      card_master_key_kcv     = m_master_key['cmk_kcv'],
      card_master_key_pos     = m_master_key['cmk_pos'],
    ]
  end
end
