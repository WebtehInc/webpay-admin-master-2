module Importers::Pagafasil
  class StandardBillPaymentTransactions

    # Create transactions:
    #   Importers::TransactionHelpers.mock_transactions
    #
    # Export payments:
    #   Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHP', :payment, '/tmp')
    #
    # Export refunds:
    #   Importers::Pagafasil::StandardBillPaymentTransactions.export('ch', 'CHR', :refund, '/tmp')
    #

    EOL_CHAR = "\r\n"

    include Importers::Helpers
    include Importers::TransactionHelpers


    private

    def build_file_name
      File.join(
        @type.to_s,
        @company_id + ff(10, @export_time.strftime("%y%m%d%H%M").to_s) + ff(3, @file_reference_number.to_i)
      )
    end

    def export_header
      rv = 'H' +                                              # record header
        ff(12, export_time.strftime("%Y%m%d%H%M").to_s) +     # file trx date
        ff(13, operator_bank_account_number.to_i) +           # beneficiary bank account
        ff(4,  build_sender_of_file) +                        # sender id
        ff(4,  receiver_of_file) +                            # receiver id
        ff(66, '')                                            # filler

      validate_line_length 100, rv

      file.write(rv + EOL_CHAR)
    end

    def export_transaction t
      validation_warning "customer number is blank in #{t.inspect}!" unless t.customer_number

      rv = 'D' +                                              # record header
        ff(12, t.customer_number.to_s) +                      # contract number
        ff(14, t.amount.to_i) +                               # amount
        ( t.type == 'credit' ? ' ' : '-' ) +                  # transaction code
        ff(8, t.created_at.strftime("%Y%m%d").to_s) +         # payment date
        ff(10, t.id.to_i % 10**10) +                          # invoice number
        'N' +                                                 # prepay Y/N
        ff(53, '')                                            # filler

      self.trx_count += 1
      self.trx_balance += t.amount.to_i

      validate_line_length 100, rv

      file.write(rv + EOL_CHAR)
    end

    def export_footer
      rv = 'T' +                                              # record header
        ff(5,  trx_count) +                                   # number of records in file
        ff(15, trx_balance) +                                 # total transaction amount
        ( type.to_s == 'payment' ? ' ' : '-' ) +              # transaction code
        ff(78, '')                                            # filler

      validate_line_length 100, rv

      file.write(rv + EOL_CHAR)
    end

    def build_sender_of_file
      if operator_code == 'ut'
        'ALP '
      else
        sender_of_file
      end
    end

    def validate!
      super
      validation_error "bank_account_number is blank in #{operator.inspect}!" unless operator.bank_account_number
      validation_error "bank_account_number must be a number in #{operator.inspect}!" unless operator.bank_account_number.to_i > 0
      validation_error "bank_account_number must be a number with up to 12 digits in #{operator.inspect}!" if operator.bank_account_number.to_i.to_s.length > 12
      validation_error "file_exchange_institution_id is blank in #{operator.inspect}!" unless operator.file_exchange_institution_id
      validation_error "file_exchange_institution_id must be up to 4 chars long in #{operator.inspect}!" if operator.file_exchange_institution_id.length > 4
    end

  end
end