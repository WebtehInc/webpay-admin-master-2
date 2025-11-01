require_relative 'update'
require_relative 'init_terminal'
require_relative 'acquiring_data'

class Terminal < Sequel::Model

  plugin :dirty
  plugin :serialization, :json, :accepted_cards, :accepted_currencies

  many_to_one :account
  one_to_one  :device
  one_to_many :transactions
  one_to_many :cashiers
  one_to_many :vouchers
  one_to_many :services_lodgments
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Terminal' }, select: [:user_id, :admin_id, :created_at, :diff]


  PUBLIC_ATTRS = self.columns - [:session_keys, :terminal_key] rescue []

end
