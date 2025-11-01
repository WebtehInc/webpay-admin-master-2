class ActivateAccount < DStruct::DStruct

  attributes strings: [:token, :password]

  def self.call(context)

    activate_account = new(context.params)

    # models
    admin = Admin.where(activation_token: activate_account.token).first

    validation_schema = Dry::Validation.Form do
      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :admin, admin

        def valid?(value)
          admin
        end
      end

      key(:password)  { filled? & size?(8..15) & strong? }
      key(:token)     { filled? & valid?}
    end

    activate_account.add_validation_schema validation_schema

    if activate_account.valid?
      password_hash = BCrypt::Password.create(activate_account.password)

      Admin.update_without_audit(admin[:id], activation_token: nil, active: true, password_hash: password_hash)
      admin
    else
      context.render_error(activate_account.errors)
    end
  end
end