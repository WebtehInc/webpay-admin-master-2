require_relative 'update'
require_relative 'attach'
require_relative 'detach'

class Device < Sequel::Model

  plugin :dirty

  many_to_one :terminal
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Device' }, select: [:admin_id, :created_at, :diff]

  PUBLIC_ATTRS = self.columns rescue []

end
