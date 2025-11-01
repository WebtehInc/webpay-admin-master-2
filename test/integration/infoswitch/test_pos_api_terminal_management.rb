require_relative "infoswitch_test_helper"

module InfoSwitch
  class TestPosApiTerminalManagement < InfoSwitchTest

    def test_configure_terminal
      resp = api.configure_terminal(m.configure_terminal)
      assert resp['server_time'], 'expected a server_time'
      assert resp['pin_key'], 'expected a pin_key'
      assert resp['pin_key_kcv'], 'expected a pin_key_kcv'
      assert resp['data_key'], 'expected a data_key'
      assert resp['data_key_kcv'], 'expected a data_key_kcv'
    end

    def test_close_day
      cd_resp1 = api.close_day(m.close_day(0))
      assert_equal 'mismatch', cd_resp1['status'], 'status is strange on the initial batch'

      # Argh => after close-day 0500s are exchanged and terminal is "settling"  so when this test is going online
      # and failing with "no active terminal acquiring accounts" then this is probably the cause, and fix is simple:
      #
      # sleep 10

      purchase_resp = api.authorize_or_purchase(m.emv_purchase)
      assert_transaction_response(purchase_resp)

      cd_resp2 = api.close_day(m.close_day(cd_resp1['batch_id'].to_i + 1).merge(purchase_amount: 10001, purchase_count: 1))
      assert_equal 'approved', cd_resp2['status'], 'status is strange on the "good" batch'
    end

  end
end
