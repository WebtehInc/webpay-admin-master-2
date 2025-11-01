class Transaction < Sequel::Model

  # PER_PAGE = 35

  self.plugin :dirty

  many_to_one :user
  many_to_one :cashier
  many_to_one :account
  many_to_one :terminal
  many_to_one :operator, key: :operator_code
  many_to_one :voucher

  # parent/child for grouping
  many_to_one :parent, class: self
  one_to_many :children, key: :parent_id, class: self

  # added new fileds:  [:response_code, :response_message, :approval_code, :acquirer, :card_data_entry]
  PUBLIC_ATTRS = [:id, :account_id, :terminal_id, :user_id, :cashier_id, # keys
                  :type, :amount, :currency, :transaction_type, :status, :services_batch_number, :description,  # common
                  :note, :balance, :systan, :created_at, :payment_method, :payment_method_type, :voided,        # common
                  :customer_number, :operator_code, # services
                  :response_code, :response_message, :approval_code, :reference_number, :acquirer] # cards

  def payment?
    ['bill_mpos', 'bill'].include? transaction_type.to_s
  end

  def public_values
    values.slice(PUBLIC_ATTRS)
  end
end
