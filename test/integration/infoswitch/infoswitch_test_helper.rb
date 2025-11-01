require_relative "../integration_helper"

module InfoSwitch
  class InfoSwitchTest < Test

    attr_accessor :m, :api, :mifare_api, :terminal_api

    def setup
      super

      @m = InfoSwitch::Mocks.new(authenticity_token: 'WebpayIntegrationPOS-test')
      @api = InfoSwitch::PosApi.new
      @mifare_api = InfoSwitch::MifareApi.new

      @terminal_api = InfoSwitch::TerminalApi.new
      @terminal = @terminal_api.create_or_update_terminal(
        @m.create_or_update_terminal.merge(
          authenticity_token: 'WebpayIntegrationPOS-test',
          name: 'WebPay Integration POS, test environment',
          transport_key: 'tmk_test',
          generate_tmk: true,
          load_balancer: 'DummyBalancer',
          default_acquirer_logid: 'xml-sim'
        )
      )
      assert_equal  'updated',@terminal['status'], "something funny happened with the infoswitch api call, response: #{@terminal}"
    end



    private

    def assert_transaction_response resp, exp = {}
      exp_status = exp[:status] || 'approved'
      exp_rc = exp[:response_code] || '0000'
      exp_response_message = exp[:response_message]

      assert_equal exp_status, resp['status'], 'status is wrong, response_message is ' + resp['response_message']
      assert_equal exp_rc, resp['response_code'], 'response_code is wrong'
      assert_equal exp_response_message, resp['response_message'], 'response_message is off' if exp_response_message
    end



  end
end
