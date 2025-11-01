require_relative "../integration_helper"

class TestCardIssuing < Test

  CARD_TTL = DownloadCardData::CARD_TTL

  def test_card_issuing

    admin = create_admin
    login_admin
    authorize_with_otp

    access_token = '356va4s5fx' # fixed access token of an NFC write initialized in InfoSwitch

    user = generate_user(last_name: 'Perić')

    # TEMP: GET route for client development
    # get "/api/issuing/prepare-card-data"
    # assert assert last_response.ok?
    # resp = JSON.parse(last_response.body)
    # access_code = resp['access_code']
    # otp_code = resp['otp_code']
    # card_data_entry = MemoryStore.get("card_data_entry_#{access_code}")
    # assert_equal access_code, card_data_entry[:access_code] # access_code printed
    # assert_equal admin.id, card_data_entry[:admin_id]       # admin_id exist in memory
    # assert_equal otp_code, admin.my_otp_code                # calculated otp code is ok

    # prepare card data
    card_serial_number = Utils.generate_random_token

    # no payload
    post "/cards/prepare-data", {}.to_json
    assert last_response.unprocessable?
    assert_equal 3, JSON.parse(last_response.body).keys.size

    # valid input
    post "/cards/prepare-data", {user_id: user.id, type: 'tag', bin: WebPayAdmin.opts[:local_card_bins].sample}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    access_code = resp['access_code']

    # otp_code is read from authenticator it is in output only for tony for development of writer
    # otp_code = resp['otp_code']
    otp_code = admin.my_otp_code

    # download card data

    # no payload
    post "/api/issuing/download-card-data", {}.to_json
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size

    # invalid digest
    post "/api/issuing/download-card-data", {access_code: access_code, otp_code: otp_code, digest: 'abc'}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid access code
    digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + 'invalid' + otp_code)
    post "/api/issuing/download-card-data", {access_code: 'invalid', otp_code: otp_code, digest: digest}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['access_code'][0]

    # invalid otp code
    digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + access_code + 'invalid')
    post "/api/issuing/download-card-data", {access_code: access_code, otp_code: 'invalid', digest: digest}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['otp_code'][0]

    # get data
    digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + access_code + otp_code)
    post "/api/issuing/download-card-data", { access_code: access_code, otp_code: otp_code,
                                              card_serial_number: card_serial_number,
                                              access_token: access_token, digest: digest,}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    check_success_download(resp, access_code, user)

    # double submit if NOT older than CARD_TTL - it will return existing record
    Card.first.update(created_at: Time.now - CARD_TTL + 10)
    post "/api/issuing/download-card-data", { access_code: access_code, otp_code: otp_code,
                                              card_serial_number: card_serial_number,
                                              access_token: access_token, digest: digest,}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    check_success_download(resp, access_code, user)

    # double submit if older than CARD_TTL - it will fail
    Card.first.update(created_at: Time.now - CARD_TTL)
    post "/api/issuing/download-card-data", { access_code: access_code, otp_code: otp_code,
                                              card_serial_number: card_serial_number,
                                              access_token: access_token, digest: digest,}.to_json
    assert last_response.unprocessable?
    assert_equal 'has already been taken', JSON.parse(last_response.body)['card_serial_number'][0]
  end

  def check_success_download(resp, access_code, user)
    # access_code: access_code, otp_code: otp_code, card_data: {public: public_data, private: private_data}, digest: digest, user_id: user.id
    card_data_entry = MemoryStore.get("card_data_entry_#{access_code}")

    puts '-' * 100
    puts 'CARD DATA RESP:' + resp.inspect
    puts
    puts 'CARD DATA MEMORY ENTRY:' + card_data_entry.inspect
    puts '-' * 100

    # we always cache response back to same memory entry
    assert_equal card_data_entry[:cached_response], resp.deep_symbolize_keys

    assert card = Card.first

    # check counts
    assert_equal 1, Card.count
    assert_equal 1, Card.first.audits.count
    assert_equal 1, user.cards.count

    private_card_data = resp['card_data']['private']
    public_card_data = resp['card_data']['public']

    # check entry in memory
    assert_equal card_data_entry[:user_id], user.id
    assert_equal card_data_entry[:type], card.type
    assert_equal card_data_entry[:bin], card.bin

    # check digest
    assert_equal resp['digest'], Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + private_card_data.values.join)

    # check cryptostuff
    assert resp['card_master_key']
    assert resp['card_master_key_kcv']

    # check generated card values
    assert_equal private_card_data['pan'][0..5], card.bin.to_s
    assert_equal private_card_data['pan'], card.pan
    assert_equal private_card_data['last_name'], 'Peric' # transliterated name
    assert_equal public_card_data['serial_number'], card.serial_number

    # check card record for computed fields
    assert_equal Card.mask_pan(card.pan), card.masked_pan
    assert_equal Digest::SHA512.hexdigest(card.pan), card.hashed_pan
    assert_equal nil, card.pin_block
  end

end
