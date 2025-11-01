class Page < Sequel::Model
  plugin :dirty

  # audits
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Page' }, select: [:admin_id, :created_at, :diff]
end