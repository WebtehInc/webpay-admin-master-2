class RemoveBankAccount < DStruct::DStruct

  attributes integers: [:account_id]

  def self.call(account_id, context)

    account = Account[account_id]

    input = new(account_id: account_id) # no struct in input as we have no attributes

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')
        option :account, account

        def empty_collection?(value)
          account.transactions.count.zero?
        end

        def inactive?(value)
          !account.active
        end
      end

      key(:account_id) { filled? & empty_collection? & inactive?}
    end

    input.add_validation_schema validation_schema

    if input.valid?
      owner = account.users.first

      DB.transaction do
        owner.remove_account(account) # delete from join table 
        owner.add_audit_message context.admin_id, "Bank account ##{account.account_number} removed"
        account.delete
      end

      context.render_success
    else
      context.render_error(input.errors)
    end
  end

end
