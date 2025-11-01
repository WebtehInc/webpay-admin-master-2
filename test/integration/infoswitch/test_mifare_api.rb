require_relative "infoswitch_test_helper"

module InfoSwitch
  class TestMifareApi < InfoSwitchTest

    # parallelize_me!

    def test_generate_master_key
      resp = mifare_api.generate_master_key(m.mifare_generate_master_key)
      assert resp['cmk_host'], 'expected a CMK for the host (us)'
      assert resp['cmk_pos'], 'expected a CMK for the Client'
      assert resp['cmk_kcv'], 'expected a CMK KCV'
    end

    def test_session_key_exchange
      resp = mifare_api.session_key_exchange(m.mifare_session_key_exchange)
      assert resp['card_challenge_response'], 'expected a card challenge response for the card'
      assert resp['csk_host'], 'expected a CSK for the host (us) - we probably wont need it though'
      assert resp['csk_pos'], 'expected a CSK for the Client'
      assert resp['csk_kcv'], 'expected a CSK KCV'
    end

    def test_session_key_exchange_with_blank_card
      resp = mifare_api.session_key_exchange(m.mifare_new_card_session_key_exchange)
      assert resp['card_challenge_response'], 'expected a card challenge response for the card'
      assert resp['csk_host'], 'expected a CSK for the host (us) - we probably wont need it though'
      assert resp['csk_pos'], 'expected a CSK for the Client'
      assert resp['csk_kcv'], 'expected a CSK KCV'
    end

    def test_generate_session_key_exchange_with_card_object
      card, card_challenge = create_card_with_challenge
      resp = mifare_api.session_key_exchange(m.req(card: card, card_challenge: card_challenge))
      assert resp['card_challenge_response'], 'expected a card challenge response for the card'
      assert resp['csk_host'], 'expected a CSK for the host (us) - we probably wont need it though'
      assert resp['csk_pos'], 'expected a CSK for the Client'
      assert resp['csk_kcv'], 'expected a CSK KCV'
    end


    private

    def create_card_with_challenge _options = {}
      # TODO: or use the real thing: m_master_key = mifare_api.generate_master_key(m.mifare_generate_master_key)
      m_master_key = m.mifare_session_key_exchange

      card_master_key         = m_master_key[:card_key]   # m_master_key['cmk_host']
      card_master_key_kcv     = 'abcdef'                  # m_master_key['cmk_kcv']
      card_challenge          = m_master_key[:card_challenge] # TODO: a comprehensive mifare mock

      bin = '1234567'
      user = User.create(first_name: 'roko', last_name: 'maroko', title: 'mr', address: 'jao', city: 'pao', zip: 'nao', country: 'faul', email: 'thisIsNotWhatNullConstraintsAreFor', phone: 'howMuchLonger?', password_hash: 'hashToYouToo', otp_code: 'otp to you too')
      card = Card.create(
        pan:        bin + '123456' + '7',
        exp_month:  Time.now.month,
        exp_year:   Time.now.year + 1,
        first_name: user.first_name,
        last_name:  user.last_name,
        bin:            bin,
        user_id:        user.id,
        serial_number:  Utils.random_pin(6),
        cmk:            card_master_key,
        cmk_kcv:        card_master_key_kcv,
      )

      [
        card,
        card_challenge
      ]
    end

  end
end