class VoucherStock < Sequel::Model
  plugin :dirty

  serializer file_name: 'voucher_stocks.json'

  many_to_one :account
  many_to_one :product

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Admin' }, select: [:user_id, :admin_id, :created_at, :diff]

end