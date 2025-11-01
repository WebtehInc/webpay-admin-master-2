require_relative "update"
require_relative "manage_accounts"

class Operator < Sequel::Model
  unrestrict_primary_key

  plugin :dirty
  plugin :serialization, :json, :email # array of emails

  one_to_many :vouchers, primary_key: :code, key: :operator_code
  one_to_many :transactions, primary_key: :code, key: :operator_code
  one_to_many :customers, primary_key: :code, key: :operator_code
  one_to_many :products, primary_key: :code, key: :operator_code

  # audits
  one_to_many :audits, key: :model_string_id, conditions: { model_name: "Operator" }, select: [:admin_id, :created_at, :diff]

  # NOTE: This needs to be atomic, or file reference numbers +will+ duplicate, been there, done that, it causes
  # bad stuff with at least Aquaelectra & Selikor
  #
  # https://stackoverflow.com/questions/38713501/sequel-ruby-how-to-increment-and-use-a-db-counter-in-a-safe-way
  def fetch_new_file_reference_number
    # DB[:table].returning(:counter).update(:counter => Sequel.expr(1) + :counter)

    fern = :file_exchange_reference_number
    fern_or_0 = Sequel.function(:coalesce, fern, 0)

    rv = DB[:operators].
      where(code: code).
      returning(fern).
      update(fern => Sequel.expr(1) + fern_or_0).
      first[fern]

    refresh
    rv
  end
end
