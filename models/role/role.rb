require_relative 'create'
require_relative 'update'

class Role < Sequel::Model
  plugin :dirty

  many_to_many :admins
  many_to_many :permissions

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Role' }, select: [:user_id, :admin_id, :created_at, :diff]

end