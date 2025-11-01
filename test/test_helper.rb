unless ENV['WP_ENV'] == 'test'
  puts
  puts '*' * 30
  puts "* WP_ENV must be set to test *"
  puts '*' * 30
  exit
end


require "vcr"
require "timecop"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :faraday
  config.ignore_localhost = true
  config.ignore_hosts 'girasol-switch' # used for acq data test which is currently live test
end

require "minitest/autorun"

class Minitest::Test

  def setup
    # wipe data
    [ :cards, :login_trails, :audits, :transactions, :vouchers, :customers, :operators, :services_lodgments, :voucher_stocks,
      :cashiers, :devices, :terminals, :accounts_users, :users, :accounts, :cashiers, :admins_roles, :permissions_roles,
      :admins, :permissions, :roles, :file_exchange_logs].each{|table| DB[table].delete}

    # cassette_name = self.class.to_s.underscore + "/" + name.gsub(/^test_[0-9]+_/, 'test_it_') # TODO: no ActiveSupport string helpers are available here
    cassette_name = subpath_of_test
    VCR.insert_cassette(cassette_name)
  end

  def teardown
    VCR.eject_cassette if VCR.current_cassette
    Timecop.return
  end

  def subpath_of_test arg = nil
    rv = self.class.to_s.gsub('::', '/') + "/" + name.gsub(/^test_[0-9]+_/, 'test_it_')
    rv += "/#{arg}" if arg
    rv
  end

  def generate_user(attrs = {})
    User.create({ address: 'address', city: "city", zip: "123456", country: "DZ", phone: "12345678",
                  first_name: "pero", last_name: "peric", birth_date: (Date.today - 18*365).to_s,
                  email: "pero@webteh.us", title: "mr", password_hash: 'abc', otp_code: 'abc'}.merge(attrs))
  end

  # :terminal_id, :account_id, :user_id, :parent_id, :type, :api_version, :application_version, :tid, :mid,
  # :systan, :entry_method, :amount, :currency, :number_of_installments, :transaction_type, :pan, :exp_date,
  # :ch_authentication, :pin_block, :ch_name, :emv_data, :track1, :track2, :track3, :approval_code, :reference_number,
  # :response_code, :response_message, :status
  def generate_transaction(attrs = {})
     Transaction.create({ amount: 12345, currency: 'USD', status: 'approved',
                          transaction_type: 'authorization', type: 'mPOS', balance: 12345}.merge(attrs))
  end

  def generate_business_account(attrs = {})
    Account.create({title: 'Simple business account', type: 'business', currency: 'USD',
                    account_number: Account.generate_account_number,
                    sell_vouchers: true, sell_prepaids: true, bill_payments: true, top_up: true, card_authorization: true,
                    merchant_name: 'Pero store',
                    merchant_address: 'Elm street 11',
                    merchant_phone: '12345678',
                    merchant_email: 'pero@example.com',
                    merchant_fax: '12345678',
                    merchant_contact: 'Pero Perić'}.merge(attrs))
  end

  # :account_id, :access_token, :terminal_key, :merchant_name, :tid, :mid, :default_currency,
  # :accepted_currencies, :accepted_cards, :number_of_installments, :receipt_text, :active
  def generate_terminal(attrs = {})
    serial_number = Utils.generate_random_token
    terminal = Terminal.create({access_token: serial_number, merchant_name: 'Merchant', terminal_key: 'abc123',
                      accepted_currencies: ['USD', 'EUR'], batch_limit: 500000, amount_limit: 50000, active: true,
                      tid: '000123', mid: '000123'}.merge(attrs))

    Device.create(type: 'pos', product_model: 'PAX-D210', serial_number: serial_number,
                  status: 'assigned', terminal_id: terminal.id, product_code: '123-456-789', assigned_at: Time.now)
    terminal
  end

  # :name, :code, :type, :active
  def generate_operator(attrs = {})
     Operator.create({name: 'Chippie', code: 'ch', type: 'voucher', currency: 'USD'}.merge(attrs))
  end

  # :operator_code, :terminal_id, :uid, :name, :value, :batch_number, :status
  def generate_voucher(attrs = {})
    v = Voucher.new({ operator_code: 'ch', uid: rand(1000000), name: 'Chippie 100', batch_number: 1,
                      status: 'available', price: 10000, currency: 'USD'}.merge(attrs))

    encrypted_data = v.encrypted_sensitive_data(value: attrs[:value] || Utils.generate_random_token)
    v.value = encrypted_data[:value]
    v.default_key_label = encrypted_data[:key_label]

    v.save_changes
  end

  # :operator_code, :number, :balance, :active
  def generate_customer(attrs = {})
     Customer.create({operator_code: 'ch', number: 12345, balance: -100000, currency: 'USD'}.merge(attrs))
  end

  def assert_equal_files exp_file_path, act_file_path, message = nil
    exp_file = File.open(exp_file_path) rescue flunk([message, "Expectation file doesn't exist (#{act_file_path} #{exp_file_path})"].compact.join(': '))
    act_file = File.open(act_file_path) rescue flunk([message, "Actual file doesn't exist (#{act_file_path} #{exp_file_path})"].compact.join(': '))

    line_no = 0
    while !exp_file.eof?
      line_no += 1
      exp_line = exp_file.readline
      act_line = act_file.readline

      if exp_line != act_line
        fault_idx = exp_line.bytes.each_with_index.detect{|c, idx| c != act_line[idx].try(:ord)}.last + 1
        exp_line_for_show = exp_line.chomp.insert(fault_idx-1, ' !!! ')
        act_line_for_show = act_line.chomp.insert(fault_idx-1, ' !!! ')
        flunk([message, "Position #{line_no}:#{fault_idx} lines differ (diff #{act_file_path} #{exp_file_path}):\nEXP: #{exp_line_for_show}\nACT: #{act_line_for_show}"].compact.join(': '))
      end
    end

    act_line = act_file.readline rescue nil # EOFError
    if act_line
      flunk([message, "Position #{line_no}:#{fault_idx} extra lines (diff #{act_file_path} #{exp_file_path}):\nEXP:\nACT: #{act_line}"].compact.join(': '))
    end

    # YAY!
    assert true
  ensure
    exp_file.try(:close)
    act_file.try(:close)
  end

end
