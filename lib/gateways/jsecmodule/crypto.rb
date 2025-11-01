module JsecModule
  class Crypto

    include JsecModule::IsoUtil

    class Error < StandardError; end
    class ServerError < Error;   end
    class ArgumentError < Error; end

    DEFAULT_INTERFACE = ENV['CRYPTO_INTERFACE'] || "luna-crypto"
    SUPPORTED_PIN_BLOCK_FORMATS = ['ISO0', 'ISO1']

    attr_writer :default_data_key_label, :default_tmk_key_label

    def encrypt clear, options = {}
      key = options.delete(:key) || default_data_key_label
      mode = options.delete(:mode) || 'data'
      iv = options.delete(:iv)

      request = {
        action: "encrypt",
        key: key,
        mode: mode
      }
      request.merge!(iv: iv) if iv
      if mode == 'data'
        clear.is_a?(Array) ? request.merge!(clear_array: clear.map{|x| to_base64(x)}) : request.merge!(clear: to_base64(clear))
      else
        clear.is_a?(Array) ? request.merge!(clear_array: clear) : request.merge!(clear: clear)
      end

      response = api_call request

      clear.is_a?(Array) ? response["encrypted_array"] : response["encrypted"]
    end

    def decrypt encrypted, options = {}
      key = options.delete(:key) || default_data_key_label
      mode = options.delete(:mode) || 'data'
      iv = options.delete(:iv)

      request = {
        action: "decrypt",
        key: key,
        mode: mode
      }
      request.merge!(iv: iv) if iv
      encrypted.is_a?(Array) ? request.merge!(encrypted_array: encrypted) : request.merge!(encrypted: encrypted)

      response = api_call request

      if mode == 'data'
        encrypted.is_a?(Array) ? response["clear_array"].map{|x| from_base64(x)} : from_base64(response["clear"])
      else
        encrypted.is_a?(Array) ? response["clear_array"] : response["clear"]
      end
    end

    def digest value
      Digest::SHA512.base64digest digest_salt + value.to_s
    end

    def default_data_key_label
      @default_data_key_label ||= ENV['DEFAULT_DATA_KEY'] || 'encdb_test'
    end

    def default_tmk_key_label
      @default_tmk_key_label ||= ENV['DEFAULT_KEK'] || 'tmk_test'
    end


    private

    def api_call hash
      require 'faraday'

      interface = hash.delete(:interface) || DEFAULT_INTERFACE

      conn = Faraday.new(:url => JsecModule.host + "/" + interface) do |builder|
        #builder.response :logger if InfoSwitch.env != :test
        builder.adapter Faraday::Adapter::NetHttp
      end

      trx_start = Time.now.to_f
      response = conn.post '', hash.to_json

      if false
        $infoswitch_crypto_request_count ||= 0; $infoswitch_crypto_request_count += 1
        $infoswitch_crypto_time_spent ||= 0.0; $infoswitch_crypto_time_spent += Time.now.to_f - trx_start
      end

      $PRY = false

      rv = JSON.parse response.body
      raise ServerError.new(rv["error"]) if rv["error"]

      rv
    end

    def digest_salt
      ENV['DIGEST_SALT'] || 'f4c42b9c7bb073d6d42bfc5c81252c8a406039ebc609eab93bacf889f0ff9610290d53637b7990e5c0cf24598e8c7746053ad611d65c0fd3e9a38b0f1ac9fd3a'
    end

    def argument_error string
      raise ArgumentError.new(string)
    end

  end
end
