class VerifyOtp < DStruct::DStruct
  DRIFT = 1*60

  attributes strings: [:otp]

  def self.call(context)
    ttl =  WebPayAdmin.opts[:otp_ttl]

    admin_id = context.admin_id
    entered_code = context.params[:otp]

    admin = Admin[admin_id]
    admin_otp_code = admin[:otp_code]

    totp = ROTP::TOTP.new(admin_otp_code)
    LOGGER.debug "OTP code: #{totp.now}"

    if (totp.verify_with_drift(entered_code, DRIFT, Time.now) rescue nil) # key can be blank
      MEMORY_STORE.set(entered_code, totp.verify_with_drift(entered_code, DRIFT, Time.now), ttl)
      MEMORY_STORE.set(admin_otp_code, true, ttl) # authorize checks for this value
    end

    verify_otp = new(otp: entered_code)
    verify_otp.add_validation_schema MyValidationSchema

    if verify_otp.valid?
      puts 'OTP valid'
      context.render_success({otp: 'valid'})
    else
      puts 'OTP error'
      context.render_error(verify_otp.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do

    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')

      def valid?(value)
        MEMORY_STORE.get value
      end
    end

    key(:otp) { filled? & numeric? & size?(6) & valid? }

  end

end
