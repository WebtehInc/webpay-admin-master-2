require_relative "integration_helper"

class TestAcquiringData < Test

  def test_acquiring_data
    return
    VCR.eject_cassette
    VCR.turn_off!(ignore_cassettes: true)

    admin = create_admin
    random = SecureRandom.uuid[0...8]
    access_token = "int-test-#{random}"
    #access_token = 'int-test-62cefec6' # deterministic token for debug
    terminal = generate_terminal(access_token: access_token)

    login_admin
    authorize_with_otp

    # test disabled acquiring feature
    FEATURES[:acquiring] = false  # disable
    get "terminals/#{terminal.id}/acquiring-data"
    assert last_response.forbidden?
    assert JSON.parse(last_response.body)['error']
    FEATURES[:acquiring] = true   # enable

    # get unknown terminal
    unknown_terminal = generate_terminal(access_token: 'unknown')
    get "terminals/#{unknown_terminal.id}/acquiring-data"
    resp = JSON.parse(last_response.body)
    assert last_response.not_found?
    assert_equal ({"status"=>"declined", "message"=>"no such terminal"}), resp
    pp resp

    # post empty terminal data
    post "terminals/#{terminal.id}/acquiring-data", {}.to_json
    assert last_response.unprocessable?
    assert_equal 5, JSON.parse(last_response.body).keys.size
    pp resp

    # post valid terminal data
    terminal.access_token = access_token
    terminal.save
    data = {
      :load_balancer=>"DummyBalancer",
      :default_acquirer_logid=>"xml-sim",
      :installment_options=>"DummyInstallments",
      :attended=>true,
      :location_indicator=>"merchant",
      :terminal_status=>"active"
    }
    post "terminals/#{terminal.id}/acquiring-data", data.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 19, resp.keys.size
    assert_equal 'created', resp['status']
    pp resp

    # update terminal
    post "terminals/#{terminal.id}/acquiring-data", data.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 'updated', resp['status']
    pp resp

    # get known terminal
    get "terminals/#{terminal.id}/acquiring-data"
    resp = JSON.parse(last_response.body)
    assert last_response.ok?
    assert_equal 18, resp.keys.size
    pp resp

    # post empty account data
    post "terminals/#{terminal.id}/acquiring-data/account/123", {}.to_json
    assert last_response.unprocessable?
    assert_equal 10, JSON.parse(last_response.body).keys.size

    # post valid account data
    data = {
      :acquirer_logid=>"xml-sim",
      :tid=>"tid-#{random}",
      :mid=>"mid-#{random}",
      :name=>"XML-SIM Test Shop",
      :city=>"Zagreb",
      :address=>"Elm street 14",
      :country=>"HR",
      :mcc=>"5411",
      :postal_code=>"1000",
      :tacq_status=>"active"
    }
    post "terminals/#{terminal.id}/acquiring-data/account/123", data.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal 19, resp.keys.size
    pp resp
  end
end
