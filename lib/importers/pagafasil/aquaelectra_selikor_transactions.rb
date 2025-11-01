module Importers::Pagafasil
  class AquaelectraSelikorTransactions

    EOL_CHAR = "\r\n"

    PSB_CRIB_NUMBER = '102242148'
    ORIGINATING_DFI_ID = '00906502'
    ROUTING_NUMBER = '20002000'
    PSB_ANP_NUMBER = '00906502'

    # Create transactions:
    #   Importers::TransactionHelpers.mock_transactions
    #
    # Export payments:
    #   Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AEP', :payment, '/tmp')
    #
    # Export refunds:
    #   Importers::Pagafasil::AquaelectraSelikorTransactions.export('ae', 'AER', :refund, '/tmp')
    #

    include Importers::Helpers
    include Importers::TransactionHelpers




    private

    # Payment file: YYYYMMDDHHMMSS_PFSAQUA_BATCHNO.TXT (aqualectra) or YYYYMMDDHHMMSS_PFSSEL_BATCHNO.TXT (selikor)
    def build_file_name
      institution_id =
        if operator_code == 'ae'
          'AQUA'
        elsif operator_code == 'se'
          'SEL'
        else
          raise "unknown operator code: #{operator_code}"
        end

      File.join(
        @type.to_s,
        "#{Time.now.strftime("%Y%m%d%H%M%S")}_PFS#{institution_id}_#{ff(7, file_reference_number)}.TXT"
      )
    end

    def export_header
      rv =
        '5' +                              # Record type code
        ff(3, build_service_class_code) +  # Service Class Code
        ff(16, "       PAGAFASIL") +       # Company name
        ff(20, build_sap_operator_name.rjust(20)) + # Company discretionary data
        build_company_identification_field +      # Company identification
        ff(3, build_service_entry_class_code) +   # Standard Entry Class (SEC) code
        ff(10, build_company_entry_description) + # Company entry description
        ff(6,  '')                              + # Company descriptive date
        ff(6,  export_time.strftime("%y%m%d"))  + # Effective entry date
        ff(3, '') +                        # Settlement date
        '1' +                              # Originator status code
        ff(8,  ORIGINATING_DFI_ID) +       # Originating DFI identification # TODO: what is?
        ff(7,  file_reference_number)      # Batch number

      validate_line_length 94, rv

      file.write(rv + EOL_CHAR)
    end

    def export_transaction t
      terminal = t.terminal
      validation_warning "customer number is blank in #{t.inspect}!" unless t.customer_number
      validation_warning "terminal is blank in #{t.inspect}!"        unless terminal

      terminal ||= Terminal.new(merchant_name: 'N/A')
      routing_number = ROUTING_NUMBER.to_i

      self.trx_count += 1
      self.trx_balance += t.amount.to_i
      @routing_number_sum ||= 0
      @routing_number_sum += routing_number

      rv =
        '6' +                 # Record type code
        build_transaction_code(t) + # Transaction code
        ff( 8, routing_number) + # Receiving DFI identification
        '0' +                 # Check digit
        ff(17, t.id) +        # DFI account number
        ff(10, t.amount.to_i) + # Amount
        ff(15, t.customer_number.to_i)      + # Individual identification number
        ff(22, terminal.merchant_name.to_s) + # Individual name # merchant name
        "  " +                       # Discretionary data
        "1"  +                       # Addenda Record indicator
        ff(8, PSB_ANP_NUMBER) + ff(7, t.id) # Trace number  (ANP PSB no (8) and Sequence7 char)

      validate_line_length 94, rv
      file.write(rv + EOL_CHAR)

      rv =
        '7' +                 # Record type code
        '05' +                # Addenda type code
        ff(80, t.created_at.strftime('%y%m%d%H%M%S')) + # Payment-related information  # "YYMMDDHHMMSS+68 spaces"
        '0001' +              # Addenda sequence number
        ff(7, t.id.to_i)      # Entry Detail sequence number # last 7 digets of the trace no of the detail record.

      validate_line_length 94, rv
      file.write(rv + EOL_CHAR)
    end

    def export_footer
      if type == :payment
        total_credit = trx_balance
        total_debit  = 0
      elsif type == :refund
        total_credit = 0
        total_debit = trx_balance
      else
        throw 'wrong type'
      end

      rv =
        '8' +                              # Record type code
        ff( 3, build_service_class_code) +  # Service Class Code
        ff( 6, trx_count) +                 # Entry/Addenda count
        ff(10, @routing_number_sum.to_i)[-10..-1] +    # Entry hash
        ff(12, total_debit) +               # Total debit amount
        ff(12, total_credit) +              # Total credit amount
        build_company_identification_field + # Company identification
        ff(19, ' ') +                       # Message Authentication Code (MAC)
        ff( 6, ' ') +                       # Reserved
        ff(8,  ORIGINATING_DFI_ID) +       # Originating DFI identification # TODO: what is?
        ff(7,  file_reference_number)      # Batch number

      validate_line_length 94, rv

      file.write(rv + EOL_CHAR)
    end


    def build_service_class_code
      if type == :payment
        '225'
      elsif type == :refund
        '220'
      else
        throw 'wrong type'
      end
    end

    def build_service_entry_class_code
      if type == :payment
        'CCD'
      elsif type == :refund
        'PPD'
      else
        throw 'wrong type'
      end
    end

    def build_company_entry_description
      if type == :payment
        ' TRANSFERS'
      elsif type == :refund
        ' REVERSALS'
      else
        throw 'wrong type'
      end
    end

    def build_company_identification_field
      '1' + ff(9, PSB_CRIB_NUMBER)         # Company identification
    end

    def build_sap_operator_name
      if operator_code == 'ae'
        rv = 'AQUA'
      elsif operator_code == 'se'
        rv = 'SELI'
      else
        raise "unknown operator code: #{operator_code}"
      end

      rv
    end

    def build_transaction_code t
      if t.transaction_type =~ /reversal/
        '27'
      else
        '22'
      end
    end

    def validate!
      super
      validation_error "file_exchange_institution_id is blank in #{operator.inspect}!" unless operator.file_exchange_institution_id
      validation_error "file_exchange_institution_id must be 2 chars long in #{operator.inspect}!" unless operator.file_exchange_institution_id.length == 2
      validation_error "file_exchange_institution_id must be either AQ or SE in #{operator.inspect}!" unless ['AQ', 'SE'].include?(operator.file_exchange_institution_id)
    end

  end
end