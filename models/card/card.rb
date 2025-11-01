require_relative 'luhnacy'
require_relative 'prepare_card_data'
require_relative 'download_card_data'

class Card < Sequel::Model
  plugin :dirty

  many_to_one :user
  one_to_many :audits, key: :model_id, conditions: { model_name: 'Card' }, select: [:user_id, :admin_id, :created_at, :diff]

  PUBLIC_ATTRS = [:id, :user_id, :type, :bin, :masked_pan, :exp_month, :exp_year, :first_name, :last_name, :active, :state, :last_access_at, :created_at]
  STATES = %w(pending activated)
  TYPES = %w(tag plastic)

  def public_values
    values.slice *PUBLIC_ATTRS
  end

  def self.mask_pan(pan)
    "#{pan[0...6]}******#{pan[-4..-1]}"
  end

end
