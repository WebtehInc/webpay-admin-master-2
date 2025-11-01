require_relative 'create'

class Customer < Sequel::Model

  many_to_one :operator, key: :operator_code
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Customer' }, select: [:user_id, :admin_id, :created_at, :diff]

  PUBLIC_ATTRS = [:id, :operator_code, :number, :balance, :currency, :creted_at]

  def public_values
    values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  end

end
