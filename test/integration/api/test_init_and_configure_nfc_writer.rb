require_relative "../integration_helper"

class Test_init_and_configure_nfc_writer < Test

  def test_init_and_configure_nfc_writer

    # prepare init data
    admin = create_admin
    login_admin
    authorize_with_otp

    # no payload
    post "/nfc-writer/prepare-init-data", {}.to_json
    resp = JSON.parse(last_response.body)
    puts 'resp:' + resp.inspect
    assert last_response.unprocessable?
    assert_equal 1, JSON.parse(last_response.body).keys.size

    # valid prepare input
    post "/nfc-writer/prepare-init-data", {writer_id: rand(WebPayAdmin.opts[:nfc_writer_access_tokens].size ) + 1}.to_json # rand starts at 0
    assert last_response.ok?, "last_response is off after prepare-init-data #{last_response.body}"
    resp = JSON.parse(last_response.body)

    access_code = resp['access_code']
    otp_code = admin.my_otp_code

    # init writer

    # no payload
    post "/api/issuing/init-nfc-writer", {}.to_json
    assert last_response.unprocessable?
    assert_equal 2, JSON.parse(last_response.body).keys.size

    # invalid access code
    post "/api/issuing/init-nfc-writer", {access_code: 'invalid', otp_code: otp_code}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['access_code'][0]

    # invalid otp code
    post "/api/issuing/init-nfc-writer", {access_code: access_code, otp_code: 'invalid'}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['otp_code'][0]

    # get data
    post "/api/issuing/init-nfc-writer", {access_code: access_code, otp_code: otp_code}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    puts 'INIT DATA RESP:' + resp.inspect

    # check resp data
    assert resp['api_key']
    assert resp['access_token']
    assert resp['tmk']
    assert resp['tmk_kcv']

    # configure writer
    access_token = resp['access_token']

    # no payload
    post "/api/issuing/configure-nfc-writer", {}.to_json
    assert last_response.unprocessable?
    assert_equal 3, JSON.parse(last_response.body).keys.size

    # invalid digest
    post "/api/issuing/configure-nfc-writer", {access_token: access_token, digest: 'abc'}.to_json
    assert last_response.unprocessable?
    assert_equal 'is invalid', JSON.parse(last_response.body)['digest'][0]

    # invalid access token
    digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + 'invalid')
    post "/api/issuing/configure-nfc-writer", {access_token: 'invalid', digest: digest}.to_json
    assert last_response.unprocessable?
    assert JSON.parse(last_response.body)['access_token'][0].include?('must be one of')

    # update writer
    systan = '12345678'
    digest = Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + access_token + systan)
    post "/api/issuing/configure-nfc-writer", {access_token: access_token, systan: systan, digest: digest}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)

    puts 'CONFIGURE RESP:' + resp.inspect

    # check response fields
    assert resp['data_key']
    assert resp['data_key_kcv']

    # check digest
    assert_equal resp['digest'], Digest::SHA512.hexdigest(WebPayAdmin.opts[:nfc_writer_api_key] + resp['data_key'] + resp['data_key_kcv'])
  end

end
