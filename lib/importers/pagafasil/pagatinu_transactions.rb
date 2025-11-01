module Importers::Pagafasil
  class PagatinuTransactions

    include Importers::Helpers

    # {:id=>7133, :terminal_id=>97, :account_id=>75, :user_id=>nil, :parent_id=>nil, :type=>"credit", :api_version=>"1.0.0.",
    #   :application_version=>"1.0.0.", :tid=>nil, :mid=>nil, :systan=>"146", :entry_method=>nil, :amount=>500, :currency=>"ANG",
    #   :number_of_installments=>nil, :transaction_type=>"prepaid_mpos", :pan=>nil, :exp_date=>nil, :ch_authentication=>nil,
    #   :pin_block=>nil, :ch_name=>nil, :emv_data=>nil, :track1=>nil, :track2=>nil, :track3=>nil, :approval_code=>nil,
    #   :reference_number=>nil, :response_code=>nil, :response_message=>nil, :status=>"approved",
    #   :created_at=>2017-11-22 11:47:01 -0400, :updated_at=>2017-11-22 11:47:01 -0400, :customer_number=>"04149031181",
    #   :operator_code=>"pa", :voucher_id=>nil, :description=>"Pagatinu voucher: 21581040888454519029",
    #   :note=>"Batch balance: 5.0 ANG", :balance=>204206, :client_datetime=>2017-11-22 11:47:04 -0400, :acquirer=>nil,
    #   :gateway=>nil, :payment_method=>"cash", :payment_method_type=>"", :services_batch_number=>17, :cashier_id=>138,
    #   :admin_id=>nil, :voided=>false}>

    # Create transactions:
    #   Importers::TransactionHelpers.mock_transactions
    #
    # Export payments:
    #   Importers::Pagafasil::PagatinuTransactions.export('pa', 'SUCCESS', :payment, '/tmp')
    #   Importers::Pagafasil::PagatinuTransactions.export('pa', 'FAIL',    :payment, '/tmp')
    #
    # Export refunds:
    #   Doesn't happen
    #

    include Importers::Helpers
    include Importers::TransactionHelpers

    attr_accessor :trx_units

    def initialize operator_code, company_id, type, output_dir, options = {}
      base_scope = Transaction.
        where(transaction_type: ['prepaid_mpos']).
        where(operator_code: operator_code)

      if company_id == 'SUCCESS'
        base_scope = base_scope.where(status: 'approved')
        _type = :success
      elsif company_id == 'FAIL'
        base_scope = base_scope.where(Sequel.~(status: 'approved'))
        _type = :fail
      elsif company_id == 'NO REFUNDS'
        base_scope = Transaction.where(false)
        _type = 'NO REALLY NO'
      else
        throw('dont understand that company_id')
      end

      @csv = FileProcessing::CsvGenerator.new(FORMAT, SEPARATORS)
      @trx_units = 0.0

      super operator_code, company_id, _type, output_dir,
        {base_scope: base_scope}.merge(options)
    end


    private

    # Batch,Transaction,Meter,Amount,Paym. Type,Units, AQ_Date, AQ_time, Date, Time, Response Code
    # ,956875,04179231818,20.00,Cash,42.10,,,20112017,001300,00
    SEPARATORS = {col_sep: ",", row_sep: "\r\n"}
    FORMAT = [
      'Batch',
      'Transaction',
      'Meter',
      'Amount',
      'Paym. Type',
      'Units',
      'AQ_Date',
      'AQ_time',
      'Date',
      'Time',
      'Response Code',
    ]

    # PSBPagatinu_20171121_045339_S.csv => successes
    # PSBPagatinu_20171121_045339_F.csv => fails
    def build_file_name
      if company_id == 'SUCCESS'
        status_indicator = 'S'
      elsif company_id == 'FAIL'
        status_indicator = 'F'
      elsif company_id == 'NO REFUNDS'
        # heh
      else
        throw('dont understand that company_id')
      end

      File.join(
        "PSBPagatinu_#{@export_time.strftime("%Y%m%d").to_s}_#{@export_time.strftime("%H%M%S").to_s}_#{status_indicator}.csv"
      )
    end

    def export_header
      rv = @csv.build_header
      file.write(rv)
    end

    def export_transaction t
      terminal = t.terminal
      validation_warning "customer number is blank in #{t.inspect}!" unless t.customer_number
      validation_warning "terminal is blank in #{t.inspect}!"        unless terminal

      rv = {}
      # 'Batch',
      rv['Batch'] = nil   # empty in file
      # 'Transaction',
      rv['Transaction'] = t.id # Ryjairo: internal counter
      # 'Meter',
      rv['Meter'] = t.customer_number
      # 'Amount',
      rv['Amount'] = to_money(t.amount)
      # 'Paym. Type',
      rv['Paym. Type'] = t.payment_method
      # 'Units',
      rv['Units'] = 'TODO'
      # 'AQ_Date', # empty in file
      rv['AQ_Date'] = nil
      # 'AQ_time', # empty in file
      rv['AQ_time'] = nil
      # 'Date',  # 20112017
      rv['Date'] = t.created_at.strftime("%Y%m%d")
      # 'Time',  # 001300
      rv['Time'] = t.created_at.strftime("%H%M%S")
      # 'Response Code',
      # Note: there seems there's no response code in the pagatinu protocol, so I'm guessing this field is free-form
      rv['Response Code'] = t.response_message.to_s

      raw = @csv.build_record(rv)

      self.trx_count += 1
      self.trx_balance += t.amount.to_i
      self.trx_units += rv['Units'].to_f

      file.write(raw)
    end

    def export_footer
      rv = {}
      # 'Batch', fixed 'Total'
      rv['Batch'] = 'Total'
      # 'Transaction', trx count
      rv['Transaction'] = trx_count
      # 'Meter', # N/A for the totals record
      rv['Meter'] = nil
      # 'Amount', sum of amounts (trx_balance)
      rv['Amount'] = to_money(trx_balance)
      # 'Paym. Type', # N/A for the totals record
      rv['Paym. Type'] = nil
      # 'Units', # sum of units
      rv['Units'] = trx_units
      # 'AQ_Date', # empty in file # N/A for the totals record
      rv['AQ_Date'] = nil
      # 'AQ_time', # N/A for the totals record
      rv['AQ_time'] = nil
      # 'Date',  # N/A for the totals record
      rv['Date'] = nil
      # 'Time',  # N/A for the totals record
      rv['Time'] = nil
      # 'Response Code'  # N/A for the totals record
      rv['Response Code'] = nil

      raw = @csv.build_record(rv)

      file.write(raw)
    end

    def validate!
      super

      unless [:success, :fail].include?(type)
        raise SkipExport.new('only payment files are supported')
      end
    end

    def to_money int
      "%.2f" % (int / 100.0).to_s
    end

  end
end