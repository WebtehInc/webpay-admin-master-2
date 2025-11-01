require_relative 'send_message'

class Message < Sequel::Model

  PUBLIC_ATTRS = [:id, :sender, :user_id, :admin_id, :parent_id, :title, :body, :read_by_user, :read_by_admin, :created_at]

  many_to_one :user
  many_to_one :admin

  # tree - self referential
  many_to_one :parent, class: self
  one_to_many :children, key: :parent_id, class: self

end