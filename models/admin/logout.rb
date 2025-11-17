class Logout
  def self.call(context)
    # Clear OTP code from memory store
    otp_code = Admin.find_value_by_attrs(:otp_code, id: context.admin_id)
    MEMORY_STORE.delete(otp_code) if otp_code
    puts 'OTP cleared.'

    # Blacklist the JWT token to invalidate the session
    if context.env['HTTP_AUTHORIZATION']
      token = context.env['HTTP_AUTHORIZATION'].split(' ').last

      # Decode token to get expiration time
      begin
        decoded = JWT.decode(token, WebPayAdmin.opts[:jwt_hmac_secret], true,
                           { algorithm: WebPayAdmin.opts[:jwt_algorithm] })
        exp_time = decoded[0]['exp']

        # Add token to blacklist with TTL matching token expiration
        if JwtBlacklist.add(token, exp_time)
          puts 'JWT token blacklisted.'
        else
          puts 'Warning: Failed to blacklist JWT token.'
        end
      rescue => e
        puts "Warning: Could not blacklist token: #{e.message}"
      end
    end

    puts msg = '=> logout successful'
    context.render_success([msg])
  end
end