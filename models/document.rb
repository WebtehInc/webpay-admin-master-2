class Document < Sequel::Model

  plugin :dirty

  many_to_one :user
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Document' }, select: [:user_id, :admin_id, :created_at, :diff]

  PUBLIC_ATTRS = [:id, :user_id, :type, :status, :comment, :file_name, :file_type, :file_size, :updated_at, :created_at]

end