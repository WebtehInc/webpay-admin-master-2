module Importers::Pagafasil
  class AquaelectraSelikorBalances

    include Importers::Helpers
    include Importers::BalanceHelpers

    # TESTING:
    #
    #   create mock with 500_000 record: Importers::Pagafasil::AquaelectraSelikorBalances.mock_file(line_no: 500_000)
    #   load the mock from the docs: Importers::Pagafasil::AquaelectraSelikorBalances.mock_file
    #
    #   import: Importers::Pagafasil::AquaelectraSelikorBalances.import_balances("/tmp/WebPay_aqse_balances_mock*")
    #


    PERCENTAGE_OF_CHANGED_RECORDS = 0.1

    # TODO: extract as "implement me"
    def self.mock_file(options = {})
      line_no = options.delete(:line_no)
      mock_file_name = options.delete(:file_name) || "/tmp/WebPay_aqse_balances_mock"

      unless line_no
        contents = <<FILE
HAQ20160601234231
DAQ       168720160525       1687    10000010
DAQ      3839320160420      38393    10000052
DAQ        30820070222        308    10000159
DAQ      5459320160525      54593    10000206
DAQ      3976320150820      39763    10000230
DAQ      2935920160525      29359    10000620
DAQ        79920120419        799    10000688
DAQ      5698920160420      56989    10000866
DAQ          020160701          0    10000874
DAQ       145320160525       1453    10000882
DAQ       150020160525       1500    10001024
TAQ      13

FILE
        padded_contents = contents.split("\n").map{|s| s}.join("\n")
        File.open(mock_file_name, 'w') {|f| f.write(padded_contents) }

      else # GENERATE!
        throw "not implemented"
      end

      return mock_file_name
    end


    # TODO: interface
    def process_header line
      @file_trx_date, @sender_of_file = parse_fixed(line,
        [  4..11,          2..3,    ],
        17
      )
      @receiver_of_file = 'PSBB'
    end

    # TODO: interface
    def process_detail_record line
      contract_no, balance_amount, due_balance, due_date_str = parse_fixed(line,
        [ 34..45,      4..14, 23..33,  15..22 ],
        45
      )
      due_date = Date.parse(due_date_str)

      # puts "Processing contract no #{contract_no.rstrip} balance #{balance_amount.to_i}"
      @detail_records_count += 1
      @balances_sum += balance_amount.to_i

      handle_sql_and_record_exceptions do
        create_or_update_customer_balances! contract_no, balance_amount,
          due_balance: due_balance, due_date: due_date
      end
    end

    # TODO: interface
    def process_trailer line
      number_of_records = parse_fixed(line, [ 4..11 ], 11).first

      # AQ & SE count header & footer also
      raise Importers::InvalidTotals, "number of lines in the file doesn't match! ours: #{@detail_records_count + 2}, theirs: #{number_of_records.to_i}" if @detail_records_count + 2 != number_of_records.to_i
    end


    private


  end
end