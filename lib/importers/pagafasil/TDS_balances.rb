module Importers::Pagafasil
  class TdsBalances

    include Importers::Helpers
    include Importers::BalanceHelpers

    # TESTING:
    #
    #   create mock with 500_000 record: Importers::Pagafasil::TdsBalances.mock_file(line_no: 500_000)
    #   load the mock from the docs: Importers::Pagafasil::TdsBalances.mock_file
    #
    #   import: Importers::Pagafasil::TdsBalances.import_balances("/tmp/WebPay_tds_balances_mock*")
    #


    PERCENTAGE_OF_CHANGED_RECORDS = 0.1

    # TODO: extract as "implement me"
    def self.mock_file(options = {})
      line_no = options.delete(:line_no)
      mock_file_name = options.delete(:file_name) || "/tmp/WebPay_tds_balances_mock"

      unless line_no
        contents = <<FILE
0000010000007420
0000030000007930
0000110000021647
0000120000024391
0000160000043315
0000170000008480
0000180000025791
0000220000002990
0000460000010282
0000470000006890
0000490000012584
0000510000000000
TD15123000000012000045497481920151230
FILE
        padded_contents = contents.split("\n").map{|s| s}.join("\r\n")
        File.open(mock_file_name, 'w') {|f| f.write(padded_contents) }

      else # GENERATE!
        throw "not implemented"
      end

      return mock_file_name
    end

    def import_balances
      DB.loggers = []
      @line_no = 0
      @insert_count = 0
      @update_count = 0
      @detail_records_count = 0
      @balances_sum = 0

      @file = File.open file_name, 'r'
      new_file_name = move_file :in_progress, file
      @file = File.open new_file_name, 'r'

      line = nil
      db_logger.start :import, :balances, @file.path
      db_logger.announce_processed_header operator_code, nil, nil, nil

      while true
        t1 = Time.now.to_f

        handle_sql_and_record_exceptions do
          DB.transaction do
            while true do
              # "sometimes" TDS doesn't have a trailer
              begin
                line = file_readline
              rescue EOFError
                line = nil
                break
              end

              # D "processing line #{@line_no}" if @line_no % 1000 == 1
              if line[0] != 'T'
                handle_sql_and_record_exceptions{ process_detail_record line }
              else line[0] == 'T'
                @footer = line
                handle_sql_and_record_exceptions{ process_trailer line }
                break
              end
              break if @line_no % RECORDS_PER_TRANSACTION == 0 # commit trx every 1000 records
            end
          end
        end

        D "EOF reached" unless line
        D "#{@line_no} inserted: #{@insert_count} updated: #{@update_count} records in #{Time.now.to_f-t1} s"
        break if !line || line[0] == 'T'
      end
      # D "processed line #{@line_no}"

      db_logger.announce_finished insert_count: @insert_count, update_count: @update_count

      # make sure end of the file is reached, file_readline will throw "EOFError: end of file reached"
      line = file_readline rescue ''
      invalid_record! line unless line == ''

      # all went fine
      move_file :processed, file
    rescue Exception => e
      db_logger.announce_error e, insert_count: @insert_count, update_count: @update_count
      log e

      if e.is_a?(Importers::Error)
        move_file :invalid, file
      else
        move_file :error, file
      end
    ensure
      file.close if file and !file.closed?
    end

    # TODO: interface
    def process_detail_record line
      contract_no, balance_amount = parse_fixed(line,
        [ 1..6,      7..16 ],
        16
      )

      # puts "Processing contract no #{contract_no.rstrip} balance #{balance_amount.to_i}"
      @detail_records_count += 1
      @balances_sum += balance_amount.to_i

      handle_sql_and_record_exceptions do
        create_or_update_customer_balances! contract_no.to_i.to_s, balance_amount
      end
    end

    # TODO: interface
    def process_trailer line
      number_of_records, total_amount_outstanding = parse_fixed(line,
        [ 9..16,            17..29  ],
        37
      )

      raise Importers::InvalidTotals, "number of lines in the file doesn't match! ours: #{@detail_records_count}, theirs: #{number_of_records.to_i}" if @detail_records_count != number_of_records.to_i
      raise Importers::InvalidTotals, "outstanding total amount doesn't match! ours: #{@balances_sum}, theirs: #{total_amount_outstanding.to_i}" if @balances_sum != total_amount_outstanding.to_i
    end


    private


  end
end