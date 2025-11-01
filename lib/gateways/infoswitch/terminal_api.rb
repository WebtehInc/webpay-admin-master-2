module InfoSwitch
  class TerminalApi

    # See InfoSwitch POS specs for details on these fields and their possible values
    PASSTHROUGH_FIELDS = [
      :__authenticity_token,
      :__secret,

      :simulate,

      :authenticity_token,
      :secret,

      :name,
      :mid,
      :tid,

      :load_balancer,
      :default_acquirer_logid,
      :installment_options,
      :attended,
      :debug,

      :location_indicator,
      :terminal_status,

      :generate_tmk,
      :transport_key,

      :tacqs

    ].freeze

    PASSTHROUGH_TACQ_FIELDS = [
      :acquirer_logid,
      :tid,
      :mid,
      :name,
      :city,
      :address,
      :country,
      :postal_code,
      :mcc,
      :tacq_status,

      :force_batch_id,

    ].freeze

    def create_or_update_terminal attrs
      attrs = secure_attrs(attrs)
      raise InfoSwitch::ApiArgumentError.new("Are you trying to kill my hand-configured integration POS?\nHugs, Borna") if attrs[:authenticity_token] == InfoSwitch::Mocks::INTEGRATION_POS_AUTHENTICITY_TOKEN

      req = InfoSwitch.merchant_keys.merge(
        random: SecureRandom.base64,
      )
      req.reverse_merge!(attrs)

      api_call 'create-or-update-terminal', req
    end

    def show_terminal attrs
      attrs = secure_attrs(attrs)
      # raise InfoSwitch::ApiArgumentError.new("Are you trying to kill my hand-configured integration POS?\nHugs, Borna") if attrs[:authenticity_token] == InfoSwitch::Mocks::INTEGRATION_POS_AUTHENTICITY_TOKEN

      req = InfoSwitch.merchant_keys.merge(
        random: SecureRandom.base64,
      )
      req.reverse_merge!(attrs)

      api_call 'show-terminal', req
    end


    private

    def secure_attrs attrs
      @stringified_passthrough_fields ||= PASSTHROUGH_FIELDS.map(&:to_s)
      @stringified_passthrough_tacq_fields ||= PASSTHROUGH_TACQ_FIELDS.map(&:to_s)

      rv = (attrs.try(:stringify_keys) || {}).slice(*@stringified_passthrough_fields).symbolize_keys
      (rv[:tacqs] || {}).each do |k, v|
        rv.dig(:tacqs)[k] = (rv.dig(:tacqs, k).try(:stringify_keys) || {}).slice(*@stringified_passthrough_tacq_fields).symbolize_keys
      end
      rv
    end

    def pci_mask raw_request, request
      rv = raw_request.clone.to_s
      request = request || {}
      if request[:track2].to_s.length > 10
        begin
          pan, other = request[:track2].split('=')
          pan[7...-4] = '-xxx-xxx-'
          other[4...7] = 'xxx'
          rv.gsub!(request[:track2], pan + "=" + other )
        rescue Exception => e
          LOGGER.warn "Error #{e.class}: #{e.message} masking track 2"
          rv.gsub!(request[:track2], 'masked track 2')
        end
      end
      rv.gsub!(request[:pan], request[:pan][0...6] + "-xxx-xxx-" + request[:pan][-4..-1]) if request[:pan].to_s.length > 10
      rv.gsub!(request[:pin_block], '********') if request[:pin_block].to_s.length >= 8
      rv.gsub!(request[:cvv], '***') if request[:cvv].to_s.length >= 3
      rv
    end

    def api_call function, request
      # extract secret from the JSON request & remove unnecessary null spam from the JSON
      raw_request = request.
        except(:__authenticity_token).
        except(:__secret).
        reject{|k,v| v.nil?}.
        to_json

      LOGGER.debug "InfoSwitch::PosApi request: #{pci_mask(raw_request, request)}"

      path = "/merchant/v1.0/#{function}"
      authenticity_token = request[:__authenticity_token]
      secret = request[:__secret]

      # TODO: validations
      raise ApiArgumentError.new("function is not present") unless function
      raise ApiArgumentError.new("__authenticity_token is not present") unless authenticity_token
      raise ApiArgumentError.new("__authenticity token must not contain blanks") if authenticity_token.to_s =~ / /
      raise ApiArgumentError.new("__secret is not present") unless secret

      http_response = faraday.post do |req|
        req.url path
        req.headers['Authorization'] = InfoSwitch::Authorizer.call(path, raw_request, authenticity_token, secret)
        req.body = raw_request
      end

      response = JSON.parse http_response.body
      LOGGER.debug "InfoSwitch::PosApi response: #{http_response.body}"

      response
    end

    def faraday
      @faraday ||= Faraday.new(:url => InfoSwitch.host) do |builder|
        builder.adapter Faraday::Adapter::NetHttp
      end
    end

  end
end
