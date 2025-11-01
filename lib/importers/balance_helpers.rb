module Importers
  module BalanceHelpers

    attr_accessor :file_name, :options
    attr_reader :insert_count, :update_count, :balances_sum

    # TODO: MOVEME to FileExchangeLog
    attr_reader :error

    attr_accessor :file

    def initialize file_name, operator_code, options = {}
      @file_name = file_name
      @options = options
      @operator = Operator.where(code: operator_code).last || raise("unknown operator with code #{operator_code}")
      @debug_header = File.basename file_name
      D "="*80
      D "STARTING: #{@file_name} #{options}"
    end

    # TODO: extract
    def import_balances

      @line_no = 0
      @insert_count = 0
      @update_count = 0
      @detail_records_count = 0
      @balances_sum = 0

      @file = File.open file_name, 'r'
      new_file_name = move_file :in_progress, file
      @file = File.open new_file_name, 'r'

      db_logger.start :import, :balances, @file.path

      @header = line = file_readline
      invalid_record! line, 'first character is off' unless line[0] == 'H'
      process_header @header
      db_logger.announce_processed_header operator_code, @file_trx_date, @receiver_of_file, @sender_of_file

      previous_import = FileExchangeLog.where(direction: 'import', operator_code: operator_code, file_type: 'balances', status: 'processed').
        where(Sequel.lit('file_timestamp >= ?', Time.parse(@file_trx_date))).last
      raise Importers::AlreadyProcessed, "see #{previous_import.values}"  if previous_import

      while true
        t1 = Time.now.to_f

        handle_sql_and_record_exceptions do
          DB.transaction do
            while true do
              line = file_readline
              # D "processing line #{@line_no}" if @line_no % 1000 == 1
              if line[0] == 'D'
                handle_sql_and_record_exceptions{ process_detail_record line }
              elsif line[0] == 'T'
                @footer = line
                handle_sql_and_record_exceptions{ process_trailer line }
                break
              else
                handle_sql_and_record_exceptions{ invalid_record!(line, 'invalid first character') }
              end
              break if @line_no % RECORDS_PER_TRANSACTION == 0 # commit trx every 1000 records
            end
          end
        end
        # D "processed line #{@line_no}"

        D "#{@line_no} inserted: #{@insert_count} updated: #{@update_count} records in #{Time.now.to_f-t1} s"
        break if line[0] == 'T'
      end

      db_logger.announce_finished insert_count: @insert_count, update_count: @update_count

      # make sure end of the file is reached, file_readline will throw "EOFError: end of file reached"
      line = file_readline rescue ''
      invalid_record! line, 'not at end of file?' unless line == ''

      # all went fine
      move_file :processed, file
    rescue Exception => e
      db_logger.announce_error e, insert_count: @insert_count, update_count: @update_count
      log e
      D e
      @error = e

      if e.is_a?(Importers::Error)
        move_file :invalid, file
      else
        move_file :error, file
      end
    ensure
      D "="*80
      file.close if file and !file.closed?
    end


    # TODO: extract
    def parse_fixed line, array, exp_length = nil
      if exp_length
        invalid_record! line, "expected length #{exp_length}" unless exp_length == exp_length
      end
      array.
        map{|range| line[(range.begin-1)..(range.end-1)]}
    end

    RECORDS_PER_TRANSACTION = 1000

    def create_or_update_customer_balances! contract_no, balance, options = {}
      contract_no = contract_no.to_s.rstrip.lstrip
      balance = balance.to_i
      query = {:number => contract_no, operator_code: operator.code} # Sequel.~(:c=>3)
      record_count = Customer.where(query).count

      due_balance = options[:due_balance].try(:to_i)
      due_date = options[:due_date]

      if contract_no.blank?
        D "blank contract number found: contract_no #{contract_no} balance: #{balance}, doing nothing"
        return
      end

      attrs = {
        balance: balance,
        currency: operator.currency,
        due_balance: due_balance,
        due_date: due_date,
        updated_at: Time.now
      }

      if record_count == 0
        Customer.create({operator_code: operator.code, number: contract_no}.merge(attrs))
        @insert_count += 1
      else
        rv = Customer.where(query).where(Sequel.~(:balance => balance)).
          update(attrs)
        @update_count += rv
      end

      if record_count > 1
        raise InvalidRecord, "something went wrong, we updated #{record_count} records by updating on #{query}"
      end
    end

    def invalid_record! line, message = nil
      raise InvalidRecord,
        ["invalid record on line number #{@line_no} (#{line.length} characters) '#{line}'", message].
          compact.join(': ')
    end

    def file_readline(line_length = nil)
      @line_no += 1
      rv = file.readline.try(:chomp)
      if line_length
        invalid_record! rv, 'invalid line length' unless rv.length == line_length
      end
      rv
    end

  end
end
