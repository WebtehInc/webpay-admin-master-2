module Importers

  module TransactionHelpers

    class SkipExport < RuntimeError; end

    def self.mock_transactions_for_operator_exports(op1, op2, options = {})
      terminal = Terminal.create(merchant_name: '12345677890123456')
      mock_payment = {terminal_id: terminal.id, type: "credit", amount:10_00, currency: "USD", transaction_type: "bill_mpos",          status: "approved", operator_code: "ch", balance:0, customer_number: SecureRandom.base64}
      mock_refund  = {terminal_id: terminal.id, type: "debit",  amount:10_00, currency: "USD", transaction_type: "bill_reversal_mpos", status: "approved", operator_code: "ch", balance:0, customer_number: SecureRandom.base64}

      # 40_00 in ch and 110_00 in ae
      Transaction.create mock_payment.merge(amount: 10_00, operator_code: op1, customer_number: '123456789')
      Transaction.create mock_payment.merge(amount: 20_00, operator_code: op2, customer_number: '098765432')
      Transaction.create mock_payment.merge(amount: 30_00, operator_code: op1, customer_number: '321457546')
      Transaction.create mock_payment.merge(amount: 40_00, operator_code: op2, customer_number: '378372972')
      Transaction.create mock_payment.merge(amount: 50_00, operator_code: op2, customer_number: '483734879')
      Transaction.create mock_payment.merge(amount: 20_00, operator_code: op2, customer_number: '483734879', voided: true)
      Transaction.create mock_payment.merge(amount: 60_00, operator_code: op1, status: 'declined', customer_number: '34897349734', response_code: 33)

      # 10_00 in ch and 20_00 in ae
      Transaction.create mock_refund.merge(amount: 10_00, operator_code: op1, customer_number: '3487397239')
      Transaction.create mock_refund.merge(amount: 20_00, operator_code: op2, customer_number: '4798347974')
      Transaction.create mock_refund.merge(amount: 30_00, operator_code: op1, status: 'declined', customer_number: '3289723972397', response_code: 35)
    end


    attr_accessor :operator_code, :options, :file, :type, :company_id, :scope
    attr_accessor :error, :sender_of_file, :receiver_of_file, :trx_count, :export_time, :file_reference_number
    attr_accessor :reexport_file

    # traditionally set by the implementation
    attr_accessor :trx_count, :trx_balance


    def initialize operator_code, company_id, type, output_dir, options = {}
      @debug_header = "#{Thread.current.object_id.to_s} #{operator_code}_#{type}"
      D "="*80
      D "STARTING: operator code: #{operator_code} company id: #{company_id} output_dir: #{output_dir} options: #{options}"
      DB.loggers = []

      if options[:reexport_file_id]
        @reexport_file = FileExchangeLog[options[:reexport_file_id]]
        raise "invalid operator code in reexport (#{operator_code} vs #{reexport_file.operator_code})" if operator_code != reexport_file.operator_code
        raise "invalid company_id in reexport (#{company_id} vs #{reexport_file.company_id})" if company_id != reexport_file.company_id
        raise "invalid type in reexport (#{type} vs #{reexport_file.file_type})" if type.to_s != reexport_file.file_type

        @export_time = reexport_file.file_timestamp
      else
        @export_time = Time.now
      end

      @operator_code = operator_code
      @company_id = company_id
      @type = type
      @options = options
      @output_dir = output_dir
      FileUtils.mkdir_p(output_dir)
      @operator = Operator.where(code: operator_code).first
      @scope = options.delete(:base_scope)

      raise UnknownOperator.new("unknown operator with code #{operator_code}") unless @operator

      unless @scope
        trx_types = if type.to_s == 'payment'
                       ['bill_mpos', 'bill']
                     elsif type.to_s == 'refund'
                       ['bill_reversal_mpos']
                     else
                       raise StandardError, "unknown type #{@type}"
                     end

        @scope = Transaction.
          where(transaction_type: trx_types).
          where(operator_code: operator_code, status: 'approved')
      end

      if @reexport_file
        @file_reference_number = @reexport_file.file_reference_number

        @scope = @scope.where(id: @reexport_file.trx_min_id..@reexport_file.trx_max_id)
      else
        @file_reference_number = operator.fetch_new_file_reference_number

        last_successful_export_scope = FileExchangeLog.where(direction: 'export', operator_code: operator_code, file_type: @type.to_s, status: 'processed').order(:id)
        last_successful_export_scope = last_successful_export_scope.where(company_id: company_id) if company_id
        last_successful_export = last_successful_export_scope.last

        @scope = @scope.where{|o| o.id > last_successful_export&.trx_max_id.to_i}
        trx_max_id = @scope.max(:id)
        @scope = @scope.where{|o| o.id <= trx_max_id}
      end
      @scope = @scope.order(:id)

      D "exporting #{@scope.count} transactions"
    end

    def export
      export_transactions
    end


    def self.export *args
      new(*args).tap{|s| s.export}
    end

    def file_exchange_log
      db_logger.try(:log)
    end




    private

    def operator_bank_account_number
      operator.bank_account_number
    end

    def validate_line_length exp_length, line
      raise Importers::ValidationError, "length #{line.length} of '#{line}' is wrong" if line.length != exp_length
    end

    def validation_warning message
      D "WARNING: #{message}"
    end

    def validation_error message
      raise Importers::ValidationError, message
    end

    # "format fixed"
    def ff length, obj
      if obj.is_a?(String)
        obj.ljust(length)[0...length]
      elsif obj.is_a?(Integer)
        obj.to_s.rjust(length, '0')[0...length]
      else
        puts caller.join("\n")
        raise RuntimeError, "unknown object class #{obj.class} of '#{obj.inspect}'"
      end
    end

    def export_transactions
      if @scope.count == 0
        D "no transactions to export, skipping"
        return
      end

      validate!
      @file_name = build_file_name
      @file_path = build_file_path :in_progress, @file_name
      @file = File.open(@file_path, 'w')

      @sender_of_file   = 'PSBB'
      @receiver_of_file = operator.file_exchange_institution_id

      @trx_count = 0
      @trx_balance = 0

      # check if exports running
      @running_exports_count = FileExchangeLog.where(direction: 'export', operator_code: operator_code, file_type: type.to_s, status: ['new', 'in_progress'], company_id: company_id).count
      raise StandardError, "#{@running_exports_count} exports already running" if @running_exports_count > 0

      db_logger.start :export, @type, @file_path, scope: @scope, company_id: @company_id, file_reference_number: @file_reference_number

      export_header
      db_logger.announce_processed_header operator_code, @export_time, @receiver_of_file, @sender_of_file

      @scope.order(:id).use_cursor.each do |t|
        D "exporting t_id: #{t.id} t_customer_number: #{t.customer_number} t_amount: #{t.amount}"
        export_transaction t
      end
      D "writing footer"
      export_footer
      D "DONE"

      db_logger.announce_finished
      @file_path = move_file :processed, file
      output_file_path = File.join(@output_dir, @file_name)

      FileUtils.mkdir_p(File.dirname(@file_path))
      FileUtils.mkdir_p(File.dirname(output_file_path))

      FileUtils.cp @file_path, output_file_path
      db_log = db_logger.log.set(file_path: output_file_path)
      db_log.save_changes
    rescue SkipExport
      # it's cool
    rescue Exception => e
      db_logger.announce_error e
      @error = e
      move_file :error, file rescue warn('no file to move')
      log e
    ensure
      D "="*80
      file.close if file and !file.closed?
    end

    # fill me with generic stuff for all importers, override me in the implementations
    def validate!
      validation_error "operator not found for operator code #{operator_code} !" unless operator
    end

    def build_file_name
      throw "DEFINE ME!"
    end

  end
end
