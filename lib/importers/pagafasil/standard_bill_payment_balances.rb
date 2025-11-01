module Importers::Pagafasil
  class StandardBillPaymentBalances

    include Importers::Helpers
    include Importers::BalanceHelpers

    # TESTING:
    #
    #   create mock with 500_000 record: Importers::Pagafasil::StandardBillPaymentBalances.mock_file(line_no: 500_000)
    #   load the mock from the docs: Importers::Pagafasil::StandardBillPaymentBalances.mock_file
    #
    #   import: Importers::Pagafasil::StandardBillPaymentBalances.import_balances("/tmp/WebPay_balances_mock*")
    #


    PERCENTAGE_OF_CHANGED_RECORDS = 0.1

    # TODO: extract as "implement me"
    def self.mock_file(options = {})
      line_no = options.delete(:line_no)
      mock_file_name = options.delete(:file_name) || "/tmp/WebPay_balances_mock"

      unless line_no
        contents = <<FILE
H201511191556ECNVPSBB
D10133       10133       000000000004200
D10134       10134       000000000004200
T00002000000000008400
FILE
        padded_contents = contents.split("\n").map{|s| s.ljust(100)}.join("\n")
        File.open(mock_file_name, 'w') {|f| f.write(padded_contents) }

      else # GENERATE!
        f = File.open(mock_file_name, 'w')
        f.puts("H#{Time.now.strftime("%Y%m%d%H%M")}ECNVPSBB".ljust(100))

        idx = 0
        ridxs = line_no.times.map{|x| x+1}.shuffle
        total_balance = 0

        line_no.times do
          subscriber_no = "S#{ridxs[idx]}".ljust(12)
          contract_no = "S#{ridxs[idx]}".ljust(12)
          balance = if rand < PERCENTAGE_OF_CHANGED_RECORDS
            rand(100) + 20
          else
            4200
          end
          total_balance += balance

          balance = balance.to_s.rjust(14)
          line = "D#{subscriber_no}#{contract_no}#{balance}".ljust(100)
          f.puts(line)

          idx += 1
        end

        f.puts "T#{idx.to_s.rjust(5)}#{total_balance.to_s.rjust(15)}".ljust(100)
        f.close
      end

      return mock_file_name
    end


    # TODO: interface
    def process_header line
      @file_trx_date, @sender_of_file, @receiver_of_file = parse_fixed(line,
        [  2..13,          14..17,          18..21 ],
        100
      )
    end

    # TODO: interface
    def process_detail_record line
      contract_no, balance_amount = parse_fixed(line,
        [ 14..25,      26..40 ],
        100
      )

      # puts "Processing contract no #{contract_no.rstrip} balance #{balance_amount.to_i}"
      @detail_records_count += 1
      @balances_sum += balance_amount.to_i

      handle_sql_and_record_exceptions do
        create_or_update_customer_balances! contract_no, balance_amount
      end
    end

    # TODO: interface
    def process_trailer line
      number_of_records, total_amount_outstanding = parse_fixed(line,
        [ 2..6,            7..21  ],
        100
      )

      raise Importers::InvalidTotals, "number of lines in the file doesn't match! ours: #{@detail_records_count}, theirs: #{number_of_records.to_i}" if @detail_records_count != number_of_records.to_i
      raise Importers::InvalidTotals, "outstanding total amount doesn't match! ours: #{@balances_sum}, theirs: #{total_amount_outstanding.to_i}" if @balances_sum != total_amount_outstanding.to_i
    end


    private


  end
end