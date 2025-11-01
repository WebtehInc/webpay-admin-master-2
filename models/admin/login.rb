class Login < DStruct::DStruct

  attributes strings: [:email, :password]

  def self.call(context)

    email = context.params[:email]
    password = context.params[:password]

    login = new(email: email, password: password)
    login.add_validation_schema MyValidationSchema

    if login.valid?
      if admin = Admin.find_all_values_by_attrs(email: email)

        # do not login inactive admins
        if !admin.active
          puts msg = "=> inactive admin trying to log in ..."
          Admin.update_without_audit(admin[:id], last_login_attempt_at: Time.now)
          context.render_error(message: {title: 'Your account is not active', body: 'Please check your email for the next step'}) and return
        end

        # do not login expired passwords
        if Time.now > admin.password_expiration_date
          puts msg = "=> admin with expired password trying to log in ..."
          Admin.update_without_audit(admin[:id], last_login_attempt_at: Time.now)
          context.render_error(message: {title: 'Your password has expired', body: 'Please reset your password'}) and return
        end

        # reset failed_login_count after login inactivity
        if (Time.now > admin[:last_login_attempt_at] + WebPayAdmin.opts[:failed_login_leeway] rescue nil)
          puts msg = "=> reseting failed login count after inactivity ..."
          Admin.update_without_audit(admin[:id], failed_login_count: 0) # last_login_attempt_at is set bellow
          admin[:failed_login_count] = 0
        end

        # block if too many failed logins
        if admin[:failed_login_count] > 2
          puts msg = "=> blocking for too many failed logins ..."
          Admin.update_without_audit(admin[:id], failed_login_count: admin[:failed_login_count] + 1, last_login_attempt_at: Time.now)
          context.render_forbidden( message: {
                                    title: 'To many failed login attempts',
                                    body: 'Your account is temporarily disabled'})
        end

        # log in
        if (BCrypt::Password.new(admin[:password_hash]) == password)
          puts msg = "=> admin logged in ..."
          # return {id: admin[:id], values: admin.to_hash.reject{|k,v| admin::NON_PUBLIC_ATTRS.include?(k)}}
          return admin
        # or increment failed login
        else
          new_failed_count = admin[:failed_login_count] + 1
          puts msg = "=> admin failed to log in, incrementing failed login count to #{new_failed_count} ..."
          Admin.update_without_audit(admin[:id], failed_login_count: new_failed_count, last_login_attempt_at: Time.now)
          return false
        end
      else
        puts 'Invalid credentials.'
      end
    else
      puts login.errors
    end
  end

  MyValidationSchema = Dry::Validation.Schema do
    key(:email) do |email|
      email.filled?
    end

    key(:password) do |password|
      password.filled?
    end
  end
end
