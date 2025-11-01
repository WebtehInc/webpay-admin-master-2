module Importers::Pagafasil
  class TdsTransactions

    EOL_CHAR = "\r\n"

    # Create transactions:
    #   Importers::TransactionHelpers.mock_transactions
    #
    # Export payments:
    #   Importers::Pagafasil::TdsTransactions.export('ch', 'CHP', :payment, '/tmp')
    #
    # Export refunds:
    #   Importers::Pagafasil::TdsTransactions.export('ch', 'CHR', :refund, '/tmp')
    #

    include Importers::Helpers
    include Importers::TransactionHelpers




    private


    def export_header
      # that's the way aha
    end

    def export_transaction t
      validation_warning "customer number is blank in #{t.inspect}!" unless t.customer_number

      rv =
        ff(7,  t.customer_number.to_i) +                      # pan / account number
        ff(10, t.amount.to_i) +                               # amount
        ( t.payment? ? '1' : '0' ) +                          # payment / refund flag, 1/0
        ff(8,  t.created_at.strftime("%Y%m%d").to_s)          # trx date

      self.trx_count += 1
      self.trx_balance += t.amount.to_i

      validate_line_length 26, rv

      file.write(rv + EOL_CHAR)
    end

    def export_footer
      rv = '9' +                                              # record header
        ff(6,  trx_count) +                                   # number of records in file
        ff(10, trx_balance) +                                 # total transaction amount
        ( type == :payment ? '1' : '0' ) +                    # payment / refund flag, 1/0
        ff(8,  Time.now.strftime("%Y%m%d").to_s)              # file date

      validate_line_length 26, rv

      file.write(rv + EOL_CHAR)
    end

    def validate!
      super
      validation_error "code must be td in #{operator.inspect}!" unless ['td'].include?(operator.code)
    end

    def build_file_name
      if type.to_s == 'payment'
        "payment/TD#{Time.now.strftime("%d%m%H%M")}pay.dta"
      else type.to_s == 'refund'
        "refund/TD#{Time.now.strftime("%d%m%H%M")}rpy.dta"
      end
    end

  end
end