require_relative 'update'
require_relative 'upload_vouchers'

class Product < Sequel::Model
  plugin :dirty

  one_to_many :audits, key: :model_id, conditions: { model_name: 'Product' }, select: [:admin_id, :created_at, :diff]
  one_to_many :vouchers
  many_to_one :operator, key: :operator_code


  def self.stock_statistics
    DB[:products___p].join(:vouchers___v, product_id: :id).
      select_group(:p__name, :p__id, :p__price, :p__currency, :p__notify_quantity, :p__type, :p__info, :p__replenished_at, :p__updated_at).
      where(v__status: 'available').select_append{count(:v__id).as(:quantity)}.
      order(:p__name).all
  end
end
