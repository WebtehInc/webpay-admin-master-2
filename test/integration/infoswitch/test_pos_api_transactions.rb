require_relative "infoswitch_test_helper"

module InfoSwitch
  class TestPosApiTransactions < InfoSwitchTest

    def test_emv_purchase
      resp = api.authorize_or_purchase(m.emv_purchase)
      assert_transaction_response resp
    end

    def test_magstripe_purchase
      resp = api.authorize_or_purchase(m.magstripe_purchase)
      assert_transaction_response resp
    end

    # this test is not parallelizable with others
    def test_magstripe_online_pin_purchase
      # first one with invalid session keys
      resp = api.authorize_or_purchase(m.magstripe_online_pin_purchase)
      assert_transaction_response resp, status: 'declined', response_code: '5002'

      # and now a proper, successful call
      pos_tmk = m.decrypt_tmk @terminal['tmk']
      assert_equal m.calculate_kcv_hex(pos_tmk), @terminal['tmk_kcv'], 'TMK KCV is funny'

      session_keys = api.configure_terminal(m.configure_terminal)
      pin_key_under_tmk = session_keys['pin_key']

      resp = api.authorize_or_purchase(m.magstripe_online_pin_purchase(tmk: pos_tmk, pin_key_under_tmk: pin_key_under_tmk, pin_key_kcv: session_keys['pin_key_kcv']))
      assert_transaction_response resp
    end

    def test_ecommerce_eci5_purchase
      skip # no need at this point (requires setting up the terminal with e-commerce flag)
      resp = api.authorize_or_purchase(m.eci05_purchase)
      assert_transaction_response resp
    end

    def test_voice_referral
      req = m.magstripe_purchase.merge(amount: 7053)
      resp = api.authorize_or_purchase(req)
      assert_transaction_response resp, status: 'referral', response_code: '1053'

      resp2 = api.authorize_or_purchase(m.voice_referral_purchase(resp, req))
      assert_transaction_response resp2
    end

    def test_authorize_and_capture_and_refund
      auth_resp = api.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))
      assert_transaction_response auth_resp

      capture_resp = api.transaction_management(m.transaction_management(:capture, auth_resp))
      assert_transaction_response capture_resp

      refund_resp = api.transaction_management(m.transaction_management(:refund, auth_resp))
      assert_transaction_response refund_resp
    end

    def test_authorize_and_void
      auth_resp = api.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))
      assert_transaction_response auth_resp

      void_resp = api.transaction_management(m.transaction_management(:void, auth_resp))
      assert_transaction_response void_resp
    end

    def test_purchase_and_refund
      purchase_resp = api.authorize_or_purchase(m.emv_purchase)
      assert_transaction_response purchase_resp

      refund_resp = api.transaction_management(m.transaction_management(:refund, purchase_resp))
      assert_transaction_response refund_resp
    end

    def test_incremental_refund_capture_void_techrev
      auth_resp = api.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))    # 10001 authorized
      assert_transaction_response(auth_resp)
      resp = api.transaction_management(m.transaction_management(:void, auth_resp).merge(amount: 1000))    #  9001 authorized
      assert_transaction_response(resp)
      resp = api.transaction_management(m.transaction_management(:capture, auth_resp).merge(amount: 2000)) #  7001 authorized, 2000 captured
      assert_transaction_response(resp)
      capture_req = m.transaction_management(:capture, auth_resp).merge(amount: 1000)
      resp = api.transaction_management(capture_req)                                                  #  6001 authorized, 3000 captured
      assert_transaction_response(resp)
      resp = api.technical_reversal(m.technical_reversal(capture_req))                                #  6001 authorized, 2000 captured
      assert_transaction_response(resp)
      resp = api.transaction_management(m.transaction_management(:refund, auth_resp).merge(amount: 1000))  #  6001 authorized, 1000 captured
      assert_transaction_response(resp)
      resp = api.transaction_management(m.transaction_management(:refund, auth_resp).merge(amount: 1000))  #  6001 authorized
      assert_transaction_response(resp)
      resp = api.transaction_management(m.transaction_management(:void, auth_resp).merge(amount: 6001))    #  0
      assert_transaction_response(resp)
    end

    def test_technical_reversal
      req = m.emv_purchase
      resp = api.authorize_or_purchase(req)
      assert_transaction_response(resp)
      resp = api.technical_reversal(m.technical_reversal(req))
      assert_transaction_response(resp)
    end

    def test_unsolicited_technical_reversal
      req = m.emv_purchase
      # resp = api.authorize_or_purchase(req)
      # assert_transaction_response(resp)
      resp = api.technical_reversal(m.technical_reversal(req))
      assert_transaction_response(resp, error: 'Transaction not found')
    end

    def test_no_DCC_because_of_card
      resp = api.prepare(m.dcc_prepare(m.magstripe_online_pin_purchase))
      dcc_resp = resp['dcc']
      assert_transaction_response(dcc_resp, status: 'declined', response_code: '1054')
    end

    def test_no_DCC_because_DCC_not_requested
      resp = api.prepare(m.no_dcc_prepare(m.dcc_magstripe_purchase))
      dcc_resp = resp['dcc']
      assert_equal nil, dcc_resp, 'expected no DCC response here'
    end

    def test_DCC
      purchase_req = m.dcc_magstripe_purchase
      prepare_resp = api.prepare(m.dcc_prepare(purchase_req))
      dcc_resp = prepare_resp['dcc']
      assert_transaction_response(dcc_resp)

      purchase_resp = api.authorize_or_purchase(m.dcc_authorize_or_purchase(prepare_resp, purchase_req))
      assert_transaction_response(purchase_resp)
      assert_equal dcc_resp["currency_exchange_rate"], purchase_resp["currency_exchange_rate"], "expected currency exchange rate like in the DCC response"
    end



  end
end