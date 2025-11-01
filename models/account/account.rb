require 'ibanizator'
require_relative 'update'
require_relative 'create'
require_relative 'add_terminal'
require_relative 'replenish_stock'

class Account < Sequel::Model

  self.plugin :dirty
  plugin :serialization, :json, :settings

  one_to_many :audits, key: :model_id, conditions: { model_name: 'Account' }, select: [:user_id, :admin_id, :created_at, :diff]
  one_to_many :transactions
  one_to_many :terminals
  one_to_many :voucher_stocks
  one_to_many :services_lodgments
  many_to_many :users

  STATES = %w(pending approved)

  PUBLIC_ATTRS = [:id, :title, :account_number, :currency, :merchant_name, :merchant_address, :balance,
                  :active, :state, :updated_at, :created_at, :type, :credit_limit, :exposure_amount]

  def public_values
    values.slice(PUBLIC_ATTRS)
  end

  def self.insert(user_id, context, opts = {})

    title = 'Simple personal account'
    currency = opts.fetch(:currency){ WebPayAdmin.opts[:default_curency] }

    account_number = generate_account_number
    iban = generate_iban(account_number)

    User[user_id].add_account({ title: title,
                                currency: currency,
                                iban: iban,
                                account_number: account_number})
  end

  def self.generate_iban(account_number)
    ibanizator = Ibanizator.new
    ibanizator.calculate_iban country_code: :ch, bank_code: '12345678', account_number: account_number.to_s
  end

  def self.generate_account_number
    (400000000 + rand(1000000000))
  end

end
