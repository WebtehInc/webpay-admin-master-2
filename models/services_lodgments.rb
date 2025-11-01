class ServicesLodgment < Sequel::Model
  plugin :dirty

  many_to_one :terminal
  many_to_one :account
  many_to_one :cashier
  one_to_many :audits, key: :model_id, conditions: { model_name: 'ServicesLodgment' }, select: [:user_id, :admin_id, :created_at, :diff]

  # PUBLIC_ATTRS = self.columns rescue []

  # def public_values
  #   values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  # end

end