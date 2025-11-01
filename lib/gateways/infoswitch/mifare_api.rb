module InfoSwitch
  class MifareApi

    # See InfoSwitch POS specs for details on these fields and their possible values
    PASSTHROUGH_FIELDS = [
      :__authenticity_token,
      :__secret,
      :card_challenge,
      :card_key,
    ]

    # m = InfoSwitch::Mocks.new
    # resp = InfoSwitch::MifareApi.new.generate_master_key(m.mifare_generate_master_key)
    def generate_master_key attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
        application_version: 'Webpay',
      }
      req.reverse_merge!(attrs)

      api_call 'generate-master-key', req
    end

    # m = InfoSwitch::Mocks.new
    # resp = InfoSwitch::MifareApi.new.session_key_exchange(m.mifare_session_key_exchange)
    def session_key_exchange attrs
      card = attrs.delete(:card)
      attrs.merge!(card_key: card.cmk) if card

      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
        application_version: 'Webpay',
      }
      req.reverse_merge!(attrs)

      api_call 'session-key-exchange', req
    end

    private

    def secure_attrs attrs
      @stringified_passthrough_fields ||= PASSTHROUGH_FIELDS.map(&:to_s)
      (attrs.try(:stringify_keys) || {}).slice(*@stringified_passthrough_fields).symbolize_keys
    end

    def api_call function, request
      # extract secret from the JSON request & remove unnecessary null spam from the JSON
      raw_request = request.
        except(:secret).
        reject{|k,v| v.nil?}.
        to_json

      LOGGER.debug "InfoSwitch::MifareApi request: #{raw_request}"

      path = "/mifare/v1.0/#{function}"
      authenticity_token = request[:__authenticity_token]
      secret = request[:__secret]

      # TODO: validations
      raise ApiArgumentError.new("function is not present") unless function
      raise ApiArgumentError.new("authenticity_token is not present") unless authenticity_token
      raise ApiArgumentError.new("authenticity token must not contain blanks") if authenticity_token.to_s =~ / /
      raise ApiArgumentError.new("secret is not present") unless secret

      http_response = faraday.post do |req|
        req.url path
        req.headers['Authorization'] = InfoSwitch::Authorizer.call(path, raw_request, authenticity_token, secret)
        req.body = raw_request
      end

      response = JSON.parse http_response.body
      LOGGER.debug "InfoSwitch::MifareApi response: #{http_response.body}"

      response
    end

    def faraday
      @faraday ||= Faraday.new(:url => InfoSwitch.host) do |builder|
        builder.adapter Faraday::Adapter::NetHttp
        # builder.response :logger, ::Logger.new(STDOUT), bodies: true
      end
    end

  end
end
