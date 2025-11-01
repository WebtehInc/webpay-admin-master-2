require_relative 'update'
require_relative 'add_bank_account'
require_relative 'remove_bank_account'

class User < Sequel::Model

  plugin :dirty

  one_to_many :audits, key: :model_id, conditions: { model_name: 'User' }, select: [:user_id, :admin_id, :created_at, :diff]
  one_to_many :login_trails
  one_to_many :transactions
  one_to_many :messages
  one_to_many :documents
  one_to_many :cards
  many_to_many :accounts

  NON_PUBLIC_ATTRS = [:password_hash, :otp_code, :activation_token, :reset_password_token]
  PUBLIC_ATTRS = (User.columns - NON_PUBLIC_ATTRS) rescue nil # test migration fails because table is not there

  def public_values
    values.except NON_PUBLIC_ATTRS
  end

end
