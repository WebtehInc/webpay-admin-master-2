class Logout
  def self.call(context)
    otp_code = Admin.find_value_by_attrs(:otp_code, id: context.admin_id)
    MEMORY_STORE.delete(otp_code) if otp_code
    puts 'OTP cleared.'
    puts msg = '=> logout successful'
    context.render_success([msg])
  end
end