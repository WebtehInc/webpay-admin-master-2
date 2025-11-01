class Permission < Sequel::Model
  plugin :dirty
  plugin :many_through_many

  many_to_many :roles
  many_through_many :admins, [[:permissions_roles, :permission_id, :role_id], [:admins_roles, :role_id, :admin_id]], distinct: true

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Permission' }, select: [:user_id, :admin_id, :created_at, :diff]

end