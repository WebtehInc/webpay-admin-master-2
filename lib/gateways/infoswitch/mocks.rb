module InfoSwitch
  class Mocks

    require 'openssl'
    include JsecModule::IsoUtil

    INTEGRATION_POS_AUTHENTICITY_TOKEN = 'WebpayIntegrationPOS'

    def initialize options = {}
      @authenticity_token = options[:authenticity_token] || INTEGRATION_POS_AUTHENTICITY_TOKEN
      @secret = options[:secret] || 'damir!1Najbolji'
    end

    def req options = {}
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
      }.merge(options)
    end

    def mifare_session_key_exchange
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
        card_key: 'tmk_test:j32c06KC8lqAyaZV46yL7Q==',  # TODO Gemalto: will not work on Luna
        card_challenge: 'nXh0F2yE6etuR//jPvgGNA=='
      }
    end

    def mifare_new_card_session_key_exchange
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
        card_key: 'tmk_test:imUVOSqSv3iKZRU5KpK/eA==',  # TODO Gemalto: will not work on Luna
        card_challenge: 'lLuBQRBEQ9i5aij0Ync3iQ=='
      }
    end

    def mifare_generate_master_key
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
      }
    end

    def create_or_update_terminal
      rv = {
        authenticity_token: 'WebpayIntegrationPOS-TerminalApi',
        secret: @secret,

        name: 'something to remember by special terminals',
        tid:  'TID',
        mid:  'Terminal', # or NFCWriter

        attended: true,
        location_indicator: 'merchant',

        terminal_status: 'active',

        load_balancer: 'NullBalancer',
        installment_options: 'NullInstallments',
      }
      if rv[:__authenticity_token] == 'WebpayIntegrationPOS-TerminalApi'
        rv.merge!(
          load_balancer: 'DummyBalancer',
          default_acquirer_logid: 'xml-sim',
          tacqs: {
            "xml-sim"=> {
              :acquirer_logid=>"xml-sim",
              :tid=>"3141592",
              :mid=>"31415926535898",
              :name=>"XML-SIM Test Shop",
              :city=>"Zagreb",
              :address=>"Otherstreet 14",
              :country=>"HR",
              :mcc=>"5411",
              :postal_code=>"1000",
              :tacq_status=>"active"
            }
          }
        )
      end

      rv
    end

    # tmk is in base64 format, as returned by InfoSwitch
    # decrypted key is returned in hex
    def decrypt_tmk tmk
      # ======================= TMK TEST ==========================
      # combined: 75648c4908ce206d513ef2ae5d3bb0c2
      # combined KCV: 8a6515
      cipher = OpenSSL::Cipher.new("des-ede")
      cipher.decrypt
      cipher.key = from_hex("75648c4908ce206d513ef2ae5d3bb0c2")
      cipher.padding = 0 # Padding is enabled by default o_O

      rv = cipher.update(from_base64(tmk)) << cipher.final
      to_hex(rv)
    end

    # key is in hex format
    def calculate_kcv_hex key
      cipher = OpenSSL::Cipher.new("des-ede")
      cipher.encrypt
      cipher.key = from_hex(key)[0..15]
      cipher.padding = 0 # Padding is enabled by default o_O

      rv = cipher.update(from_hex('0000000000000000')) << cipher.final
      to_hex(rv)[0...6]
    end

    def technical_reversal transaction_request
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?

        original_systan: transaction_request[:systan],
        reversal_reason: 'timeout'
      }
    end

    # command: refund, capture or void
    def transaction_management command, authorize_or_purchase_response
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?

        transaction_type: command,
        amount:   authorize_or_purchase_response['amount'],
        currency: authorize_or_purchase_response['currency'],
        original_rrn: authorize_or_purchase_response['reference_number']
      }
    end

    # the POS request must match batch_id and the counts of the server, it's very important that this is implemented
    # properly because this is usually the only way to know if something is going wrong, and things do go wrong
    def close_day batch_id, options = {}
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        batch_id: batch_id,

        authorize_amount: 0,
        authorize_count: 0,
        purchase_amount: 0,
        purchase_count: 0,
        capture_amount: 0,
        capture_count: 0,
        void_amount: 0,
        void_count: 0,
        refund_amount: 0,
        refund_count: 0,
      }
    end

    def configure_terminal
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,
      }
    end

    def dcc_prepare authorize_or_purchase_mock
      authorize_or_purchase_mock.merge(
        exp_transaction_type: authorize_or_purchase_mock[:transaction_type],
        dcc: true,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
      )
    end

    def no_dcc_prepare authorize_or_purchase_mock
      authorize_or_purchase_mock.merge(
        exp_transaction_type: authorize_or_purchase_mock[:transaction_type],
        dcc: false,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
      )
    end

    def dcc_authorize_or_purchase prepare_response, authorize_or_purchase_mock
      dcc = prepare_response['dcc'] || {}
      authorize_or_purchase_mock.
        merge(
          created_at: Time.now,           # created_at of the trx
          systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
          dcc_rrn: dcc['reference_number'],
          dcc_accepted_by_client: true
        )
    end

    def voice_referral_purchase voice_referral_response, authorize_or_purchase_mock
      authorize_or_purchase_mock.
        merge(
          created_at: Time.now,           # created_at of the trx
          systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
          voice_referral_rrn: voice_referral_response['reference_number'],
          offline: true,
          approval_code: '123456'         # generated by the POS in case of offline trxs
        )
    end

    def magstripe_purchase
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        transaction_type: 'purchase',   # or authorize
        amount: 10001,                  # 10000 if you want a decline
        currency: 840,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
        cardholder_authentication: 'signature',
        card_data_entry: 'magstripe',
        pan:    '4111111111111111',
        track2: '4111111111111111=17073011818341800000',
        expiration_date: '1707',
        pos_entry_mode:  '012'
      }
    end

    def dcc_magstripe_purchase
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        transaction_type: 'purchase',   # or authorize
        amount: 10001,                  # 10000 if you want a decline
        currency: 191,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
        cardholder_authentication: 'signature',
        card_data_entry: 'magstripe',
        pan:    '4222222222222220',
        track2: '4222222222222220=17073011818341800000',
        expiration_date: '1707',
        pos_entry_mode:  '012'
      }
    end

    # will be declined with "RC 5002: Invalid session PIN key, execute configure-terminal"
    # if you don't supply correct pin_key_under_tmk && tmk options
    def magstripe_online_pin_purchase options = {}
      pin_key_under_tmk = options[:pin_key_under_tmk]
      tmk = options[:tmk]
      pin_key_kcv = options[:pin_key_kcv]
      pin_block = nil

      if pin_key_under_tmk && tmk
        # STEP 1: decrypt pin_key_under_tmk
        cipher = OpenSSL::Cipher.new("des-ede")
        cipher.decrypt
        cipher.key = from_hex(tmk)[0..15]
        cipher.padding = 0 # Padding is enabled by default o_O

        pin_key = cipher.update(from_base64(pin_key_under_tmk)) << cipher.final

        binding.pry if pin_key_kcv != calculate_kcv_hex(to_hex(pin_key)) if pin_key_kcv

        # STEP 2: take a valid pin block and encrypt it
        # 044326cff769fffe is a clear PIN block that works with 5413330089600010 card
        clear_pin_block = '044326cff769fffe'

        cipher = OpenSSL::Cipher.new("des-ede")
        cipher.encrypt
        cipher.key = pin_key[0..15]
        cipher.padding = 0 # Padding is enabled by default o_O

        pin_block = cipher.update(from_hex(clear_pin_block)) << cipher.final
        pin_block = to_hex(pin_block)[0...16]
      end

      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        transaction_type: 'purchase',   # or authorize
        amount: 10001,                  # 10000 if you want a decline
        currency: 840,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
        cardholder_authentication: 'online pin',
        card_data_entry: 'magstripe',
        pan:    '5413330089600010',
        track2: '5413330089600010=17073011818341800000',
        expiration_date: '1707',
        pos_entry_mode:  '012',
        pin_block: pin_block || '1234567812345678',
        pin_block_format: 'ISO0'
      }
    end

    def emv_purchase
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        transaction_type: 'purchase',   # or authorize
        amount: 10001,                  # 10000 if you want a decline
        currency: 840,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
        cardholder_authentication: 'offline pin',
        card_data_entry: 'emv',
        pan:    '4111111111111111',
        track2: '4111111111111111=17072011818341800000',
        expiration_date: '1707',
        pos_entry_mode:  '051',

        emv_data: {
            "5F34"=>"01",
            "84"=>"A0000000049999C000010560",
            "8F"=>"04",
            "82"=>"5800",
            "95"=>"0000001000",
            "9A"=>"100109",
            "9C"=>"00",
            "9F36"=>"0001",
            "9F37"=>"D8B57618",
            "9F26"=>"45B2B2B634ADB290",
            "9F27"=>"80",
            "9F10"=>"0D10A50003020800C75900000000000000FF",
            "9F34"=>"410302",
            "9F33"=>"E0F0C8",
            "9F02"=>"000000010001",
            "9F03"=>"000000000000",
            "9F08"=>"0000",
            "9F09"=>"0000",
            "9F1E"=>"00000000",
            "9F1A"=>"0191",
            "5F2A"=>"0840",
            "9F35"=>"22",
            "9F41"=>"1234"
        }
      }
    end

    def eci05_purchase
      {
        __authenticity_token: @authenticity_token,
        __secret: @secret,

        transaction_type: 'purchase',   # or authorize
        amount: 10001,                  # 10000 if you want a decline
        currency: 840,
        created_at: Time.now,           # created_at of the trx
        systan: rand(10**6),            # make me a sequence, so it's the same for the same transaction, trx record ID?
        cardholder_authentication: '3d-secure',
        card_data_entry: 'e-commerce',
        pan:    '4111111111111111',
        expiration_date: '1707',

        cvv:  '1234',
        eci:  '05',
        cavv: 'AAABBJg0VhI0VniQEjRWAAAAAAA=',
        xid:  '12345678910111214037',
        veres_status: 'Y',
        pares_status: 'Y',

        ch_full_name: 'Roko Maroko',
        ch_address: 'An address 632b',
        ch_phone: '+385 90 123 4567',
        ch_city: 'Zagreb',
        ch_ip: '127.0.0.1',
        ch_country: 'HR'
      }
    end

  end
end
