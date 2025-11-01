require_relative 'update'

class Fee < Sequel::Model
  plugin :dirty

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Fee' }, select: [:admin_id, :created_at, :diff]
end