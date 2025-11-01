class ResetPassword < DStruct::DStruct

  attributes strings: [:password]

  def self.call(admin, context)
    password = context.params[:password]

    reset_password = new(password: password)
    reset_password.add_validation_schema MyValidationSchema

    if reset_password.valid?
      old_password_hash = admin.password_hash
      new_password_hash = BCrypt::Password.create(password)

      # add new hash to history array
      unless admin.password_history
        old_password_hashes = [old_password_hash] # first entry
      else
        old_password_hashes = admin.password_history.split(",")
        old_password_hashes.unshift(old_password_hash)
        old_password_hashes = old_password_hashes[0...4] # keep last four
      end

      # reject repeated passwords
      old_password_hashes.each do |old_password_hash|
        if BCrypt::Password.new(old_password_hash) == password
          context.render_error(password: ['should be different from previous four passwords'])
        end
      end

      updated_values = {
        password_history: old_password_hashes.join(","),
        password_hash: new_password_hash,
        reset_password_token: nil,
        password_expiration_date: Time.now + 3600 * 24 * 90
      }
      Admin.update_without_audit(admin.id, updated_values)
    else
      context.render_error(reset_password.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    configure do
      config.predicates = SchemaPredicates
      config.messages_file = Pathname(__dir__).join('../errors.yml')
    end
    key(:password) { filled? & size?(8..15) & strong? }
  end

end
