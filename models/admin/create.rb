class CreateAdmin < DStruct::DStruct

  attributes  strings:  [:first_name, :last_name, :email, :phone],
              booleans: [:superuser]

  def self.call(context)

    create_admin = new(context.params)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        def unique?(value)
          !Admin.where(email: value).first
        end
      end

      key(:email)       { filled? & email? & unique? }

      # profile
      key(:first_name)  { filled? & alpha? & size?(2..20) }
      key(:last_name)   { filled? & alpha? & size?(2..20) }
      key(:phone)       { filled? & numeric? & size?(8..15) }
      # key(:active)      { bool? } # activtion is via email
      key(:superuser)   { bool? }
    end

    create_admin.add_validation_schema validation_schema

    if create_admin.valid?

      # password_hash = BCrypt::Password.create(params[:password])
      admin_values = {
        otp_code: Utils.generate_random_token,
        activation_token: Utils.generate_random_token,
        password_hash: "",
        password_expiration_date: Time.now + 3600 * 24 * 90
      }

      # send activation email
      if admin = Admin.create(create_admin.to_h.merge(admin_values))
        Mailer.sendmail('/admin/activate', admin)
        context.render_success(message: "Activation email is sent to #{admin.email}.")
      end
    else
      context.render_error(create_admin.errors)
    end
  end
end
