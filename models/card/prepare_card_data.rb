class PrepareCardData < DStruct::DStruct

  attributes integers: [:user_id, :bin], strings: [:type]

  def self.call(context)

    input = new(context.params)
    admin = Admin[context.admin_id]

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
      end

      key(:user_id) { filled? & int? }
      key(:type)    { inclusion?(Card::TYPES) }
      key(:bin)     { filled? & int? }
    end

    input.add_validation_schema validation_schema

    if input.valid?
      access_code = Utils.random_pin(6)
      otp_code = admin.my_otp_code
      store_card_data_entry_in_cache(access_code, otp_code, input, context.admin_id)
      context.render_success(access_code: access_code)
    else

      # # TODO: remove response for GET, it is used for easier client development
      # if context.request.is_get?
      #   card_data_access_codes_for_random_user_for_test(context)
      # else
      #   context.render_error(input.errors)
      # end

      context.render_error(input.errors)
    end
  end

  def self.store_card_data_entry_in_cache(access_code, otp_code, input, admin_id)
    MemoryStore.set("card_data_entry_#{access_code}", # scoped to access_code for multiple entries
                                      { access_code: access_code,
                                        # otp_code: otp_code, # we calculate this now
                                        type: input.type,
                                        bin: input.bin,
                                        user_id: input.user_id,
                                        admin_id: admin_id}, WebPayAdmin.opts[:access_code_ttl])
  end

  # TODO: remove this, used for client development
  # def self.card_data_access_codes_for_random_user_for_test(context)
  #
  #   # random codes
  #   access_code = Utils.random_pin(6)
  #
  #   # random user_id
  #   first_user_id = User.first.id
  #   last_user_id = User.last.id
  #   user_id = rand first_user_id..last_user_id
  #
  #   # random bin
  #   bin = WebPayAdmin.opts[:local_card_bins].sample
  #
  #   # random admin
  #   admin = Admin.first
  #   otp_code = admin.my_otp_code # Utils.random_pin(6)
  #
  #   store_card_data_entry_in_cache(access_code, otp_code, self.new(user_id: user_id, type: 'tag', bin: bin), admin.id)
  #   context.render_success(access_code: access_code, otp_code: otp_code) # we output otp_code, tony does not have authenticator
  # end
end
