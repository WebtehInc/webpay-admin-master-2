require_relative "../integration_helper"

module Gateway
  class CryptoTest < Test

    KEY_LENGTH = [24, 32]
    KCV_LENGTH = 6

    def setup
      super
      @crypto = JsecModule::Crypto.new
    end

    def test_decrypting_nil_in_an_array_does_nothing_funny
      assert_equal [nil], @crypto.decrypt([nil]),
        "the crypto interface returned a wrong value"
    end

    def test_encrypt_decrypt_with_kek
      clear = "12345"
      assert_equal clear, @crypto.decrypt(@crypto.encrypt(clear)),
        "the crypto interface returned a wrong value"
    end

    def test_encrypt_decrypt_array_with_kek
      clear = ["12345", "54321", "dreaming of summer..."]
      assert_equal clear, @crypto.decrypt(@crypto.encrypt(clear)),
        "the crypto interface returned a wrong value"
    end

  end
end
