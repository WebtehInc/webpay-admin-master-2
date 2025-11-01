require 'bcrypt'
require 'rotp'

# public
require_relative 'login'
require_relative 'logout'
require_relative 'activate'
require_relative 'reset_password'
require_relative 'create'
require_relative 'update'

# private
require_relative 'verify_otp'
require_relative 'login_trail'

class Admin < Sequel::Model
  plugin :dirty
  plugin :many_through_many

  one_to_many :login_trails
  one_to_many :messages
  one_to_many :revealed_vouchers, primary_key: :id, key: :revealed_by, :class=>:Voucher

  # permissions
  many_to_many :roles
  many_through_many :permissions, [[:admins_roles, :admin_id, :role_id], [:permissions_roles, :role_id, :permission_id]], distinct: true

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Admin' }, select: [:user_id, :admin_id, :created_at, :diff]

  # changes
  one_to_many :changes, key: :admin_id, class: :Audit # all audit records made by this admin

  PUBLIC_ATTRS = [:id, :first_name, :last_name, :phone, :email, :active, :superuser, :last_login_at, :created_at, :updated_at]

  def public_values
    values.slice *PUBLIC_ATTRS
  end

  # for access tokens for devices init and downloading configs/data
  def my_otp_code
    ROTP::TOTP.new(otp_code).now
  end

  # for signup
  def self.signup(signup_hash)
    create(signup_hash)
  end

  # for login
  def self.update_without_audit(id, attrs={})
    DB[:admins].where(id: id).update(attrs)
  end

  def self.update_login_data(id, old_user, context)
    update_without_audit(id,  login_count: (old_user[:login_count] + 1), failed_login_count: 0, last_login_at: Time.now,
                              last_login_attempt_at: Time.now, last_login_ip: context.env['HTTP_X_FORWARDED_FOR'] || context.env['REMOTE_ADDR'])
  end

end
