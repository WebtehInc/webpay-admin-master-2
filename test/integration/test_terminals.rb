require_relative "integration_helper"

class TestTerminals < Test

  def test_add_terminal

    admin = create_admin
    login_admin
    authorize_with_otp

    account = generate_business_account

    post "/accounts/#{account.id}/add-terminal", {}.to_json
    assert last_response.unprocessable?
    assert_equal 14, JSON.parse(last_response.body).keys.size

    terminal_settings = {
      merchant_name: account.merchant_name,
      merchant_address: account.merchant_address,
      merchant_phone: account.merchant_phone,
      merchant_email: account.merchant_email,
      merchant_fax: account.merchant_fax,
      merchant_contact: account.merchant_contact,
      receipt_text: 'Receipt text', cashiers_full_name: 'Johnny Cashier',
      opening_hours: 1, opening_minutes: 1, closing_hours: 11, closing_minutes: 11, active: true
    }

    # unknown serial
    post "/accounts/#{account.id}/add-terminal", common_terminal_attrs(account).merge(access_token: '1234567890').to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert_equal 'is not available', resp['access_token'][0]

    # serial ok
    device = Device.create( type: 'pos', product_model: 'PAX-D210', serial_number: Utils.generate_random_token,
                            status: 'idle', terminal_id: nil, product_code: '123-456-789')

    post "/accounts/#{account.id}/add-terminal", common_terminal_attrs(account).merge(access_token: device.serial_number).to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 4, resp.keys.size

    terminal = Terminal.first

    # old workflow
    assert_equal terminal.id, resp['id']
    assert_equal terminal.terminal_key, resp['api_key']
    assert resp['cashier_pin']
    # new workflow
    assert resp['access_code']
    access_code = resp['access_code'] # needed for init step

    # check init data in memory
    check_init_data_in_memory MemoryStore.get(:terminal_init_data_entry)

    # relations
    assert device.reload.terminal
    assert terminal.reload.device

    # attrs updates
    assert terminal.access_token, device.serial_number
    assert_equal 'assigned', device.status

    # already assigned serial
    post "/accounts/#{account.id}/add-terminal", terminal_settings.merge(access_token: device.serial_number).to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert_equal 'has already been taken', resp['access_token'][0]


    # download init data
    otp_code = admin.my_otp_code

    # no payload
    post "/api/terminal/init", {}.to_json
    assert last_response.unprocessable?
    assert_equal 2, JSON.parse(last_response.body).keys.size

    # invalid access code
    post "/api/terminal/init", {access_code: 'invalid', otp_code: otp_code}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['access_code'][0]

    # invalid otp code
    post "/api/terminal/init", {access_code: access_code, otp_code: 'invalid'}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['otp_code'][0]

    # get data
    post "/api/terminal/init", {access_code: access_code, otp_code: otp_code}.to_json
    resp = JSON.parse(last_response.body)

    puts 'INIT DATA RESP:' + resp.inspect
    assert last_response.ok?

    # check resp data
    assert resp['terminal_id']
    assert resp['terminal_key']
    assert resp['tmk']
    assert resp['tmk_kcv']

  end

  def test_remove_and_add_device

    admin = create_admin
    login_admin
    authorize_with_otp

    account = generate_business_account

    device = Device.create( type: 'pos', product_model: 'PAX-D210', serial_number: Utils.generate_random_token,
                            status: 'idle', terminal_id: nil, product_code: '123-456-789')
    # create new terminal with device
    post "/accounts/#{account.id}/add-terminal", common_terminal_attrs(account).merge(access_token: device.serial_number).to_json
    assert last_response.ok?

    # remove existing device
    post "/devices/#{device.id}/detach", common_terminal_attrs(account).merge(access_token: device.serial_number).to_json
    assert last_response.ok?

    # check terminal updates
    terminal = Terminal.last
    refute terminal.access_token
    refute terminal.terminal_key

    # check device updates
    device.reload
    refute device.terminal_id
    assert_equal 'idle', device.status

    # try to remove device again
    post "/devices/#{device.id}/detach", common_terminal_attrs(account).merge(access_token: device.serial_number).to_json
    assert last_response.unprocessable?
    assert_equal 'cannot remove device', JSON.parse(last_response.body)[0]

    # attach new device
    device = Device.create( type: 'pos', product_model: 'PAX-D210', serial_number: Utils.generate_random_token,
                            status: 'idle', terminal_id: nil, product_code: '123-456-789')
    post "/devices/#{device.id}/attach", {terminal_id: terminal.id}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    # old workflow
    terminal.reload
    assert_equal terminal.id, resp['id']
    assert_equal terminal.terminal_key, resp['api_key']

    # new workflow
    assert resp['access_code']

    # check init data in memory
    check_init_data_in_memory MemoryStore.get(:terminal_init_data_entry)

    # download init data
    access_code = resp['access_code']
    otp_code = admin.my_otp_code

    # get data
    post "/api/terminal/init", {access_code: access_code, otp_code: otp_code}.to_json
    resp = JSON.parse(last_response.body)

    puts 'INIT DATA RESP:' + resp.inspect
    assert last_response.ok?

    # check resp data
    assert resp['terminal_id']
    assert resp['terminal_key']
    assert resp['tmk']
    assert resp['tmk_kcv']

    # try to atach again
    post "/devices/#{device.id}/attach", {terminal_id: terminal.id}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    # puts resp.inspect
    assert_equal 'is not available', resp['terminal_id'][0]
  end

  def common_terminal_attrs(account)
    {
      merchant_name: account.merchant_name,
      merchant_address: account.merchant_address,
      merchant_phone: account.merchant_phone,
      merchant_email: account.merchant_email,
      merchant_fax: account.merchant_fax,
      merchant_contact: account.merchant_contact,
      receipt_text: 'Receipt text', cashiers_full_name: 'Johnny Cashier',
      opening_hours: 1, opening_minutes: 1, closing_hours: 11, closing_minutes: 11, active: true
    }
  end

  def check_init_data_in_memory(entry)
    assert entry[:terminal_id]
    assert entry[:terminal_key]
    assert entry[:tmk]
    assert entry[:tmk_kcv]
    assert entry[:access_code]
    assert entry[:admin_id]
  end

end
