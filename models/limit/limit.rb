require_relative 'update'

class Limit < Sequel::Model
  plugin :dirty

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Limit' }, select: [:admin_id, :created_at, :diff]
end