class Setting < Sequel::Model
  unrestrict_primary_key

  plugin :dirty
  plugin :serialization, :json, :value # array of values

  # audits
  one_to_many :audits, key: :model_string_id, conditions: { model_name: 'Setting' }, select: [:admin_id, :created_at, :diff]
end
