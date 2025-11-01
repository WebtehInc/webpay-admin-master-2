class Cashier < Sequel::Model
  plugin :dirty

  many_to_one :terminal
  one_to_many :transactions
  one_to_many :services_odgments
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Cashier' }, select: [:user_id, :admin_id, :created_at, :diff]

  # PUBLIC_ATTRS = [:tid, :mid, :merchant_name, :active, :updated_at]
  #
  # def public_values
  #   values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  # end

end