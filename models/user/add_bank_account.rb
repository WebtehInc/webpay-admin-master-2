class AddBankAccount < DStruct::DStruct

  attributes strings: [:account_number, :type]

  def self.call(id, context)

    user = User[id]

    bank_account = new(context.params)

    validation_schema = Dry::Validation.Form do

      configure do
        config.predicates = SchemaPredicates
        config.messages_file = Pathname(__dir__).join('../errors.yml')

        def unique?(value)
          !Account.where(account_number: value).first
        end
      end

      key(:account_number)        { numeric? & size?(8..16) & unique?}
      key(:type)                  { filled? & inclusion?(BANK_ACCOUNT_TYPES.keys.stringify) }
    end

    bank_account.add_validation_schema validation_schema

    if bank_account.valid?

      DB.transaction do
        account = Account.create_with_audit(context.admin_id,
                                            bank_account.to_h.merge(title:     "#{WebPayAdmin.opts[:bank_name]} #{bank_account.type} account",
                                                                    currency:  WebPayAdmin.opts[:default_curency],
                                                                    active:    false,
                                                                    state: 'pending'))
        user.add_account account
        user.add_audit_message context.admin_id, "Bank account ##{account.account_number} associated"
        account.add_audit_message context.admin_id, "Client #{user.first_name} #{user.last_name} associated"
      end

      context.render_success
    else
      context.render_error(bank_account.errors)
    end
  end

end
