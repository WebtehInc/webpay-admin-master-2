module InfoSwitch
  class PosApi

    # See InfoSwitch POS specs for details on these fields and their possible values
    PASSTHROUGH_FIELDS = [
      :__authenticity_token,
      :__secret,

      :application_version,

      :transaction_type,
      :amount,
      :currency,
      :number_of_installments,
      :created_at,
      :systan,

      :cardholder_authentication,
      :card_data_entry,

      :pan,
      :track2,            # skip for e-commerce
      :expiration_date,
      :pos_entry_mode,    # skip for e-commerce

      :emv_data,          # only for EMV, EMV_CLESS
      :pin_block,         # only for online pin
      :pin_block_format,  # only for online pin
      :cvv,

      # following is e-commerce only:
      :eci,
      :cavv,
      :xid,
      :veres_status,
      :pares_status,
      :ch_full_name,
      :ch_address,
      :ch_phone,
      :ch_city,
      :ch_ip,
      :ch_country,

      # for offline transactions:
      :offline,
      :voice_referral_rrn,
      :approval_code,

      # for DCC
      :dcc_rrn,
      :dcc_accepted_by_client,

      # for extra goodies
      :custom,

      # for prepare-transaction API
      :exp_transaction_type,
      :dcc,

      # for transaction management
      :original_rrn,

      # for technical reversals
      :original_systan,
      :reversal_reason,

      # for close-day
      :batch_id,
      :authorize_amount,
      :authorize_count,
      :purchase_amount,
      :purchase_count,
      :capture_amount,
      :capture_count,
      :void_amount,
      :void_count,
      :refund_amount,
      :refund_count,
    ].freeze

    # m = InfoSwitch::Mocks.new
    # EMV purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase)
    # Magstripe purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.magstripe_purchase)
    # Magstripe online PIN purchase (will fail with RC 5002):
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.magstripe_online_pin_purchase)
    # E-commerce ECI 5 purchase:
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.eci05_purchase)
    # Voice referral transaction:
    #   req = m.magstripe_purchase.merge(amount: 7053)
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(req)
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.voice_referral_purchase(resp, req))
    def authorize_or_purchase attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
      }
      req.reverse_merge!(attrs)

      api_call 'authorize-or-purchase', req
    end

    # TRANSACTION MANAGEMENT: capture, void, refund
    #
    # m = InfoSwitch::Mocks.new
    #
    # Authorize + Capture + Refund:
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:capture, resp))
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:refund, resp))
    # Authorize + Void:
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:void, resp))
    # Purchase + Refund:
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase)
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:refund, resp))
    #
    # All versions of partial & incremental voiding, refunding, capturing, with techrev branfuckery also works, but it's
    # usually not used on POSes (this is e-commerce mostly stuff):
    #
    #   resp = InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase.merge(transaction_type: 'authorize'))    # 10001 authorized
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:void, resp).merge(amount: 1000))    #  9001 authorized
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:capture, resp).merge(amount: 2000)) #  7001 authorized, 2000 captured
    #   capture_req = m.transaction_management(:capture, resp).merge(amount: 1000)
    #   InfoSwitch::PosApi.new.transaction_management(capture_req)                                                  #  6001 authorized, 3000 captured
    #   InfoSwitch::PosApi.new.technical_reversal(m.technical_reversal(capture_req))                                #  6001 authorized, 2000 captured
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:refund, resp).merge(amount: 1000))  #  6001 authorized, 1000 captured
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:refund, resp).merge(amount: 1000))  #  6001 authorized
    #   InfoSwitch::PosApi.new.transaction_management(m.transaction_management(:void, resp).merge(amount: 6001))    #  0
    def transaction_management attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
      }
      req.reverse_merge!(attrs)

      api_call req[:transaction_type], req
    end

    # m = InfoSwitch::Mocks.new
    #
    # A techrev means "as far as I am concerned, that trx that I sent before didn't happen, I want to make sure we are
    # on the same page" => this is the fundamental difference from a void/refund.
    #
    # Also, a techrev can be applied to a void/refund if the acquirer supports incremental trx management, while a
    # void/refund can only be applied to an authorization/purchase.
    #
    # A technical reversal flow with a purchase:
    #   req = m.emv_purchase
    #   InfoSwitch::PosApi.new.authorize_or_purchase(req)
    #   InfoSwitch::PosApi.new.technical_reversal(m.technical_reversal(req))
    def technical_reversal attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,

        transaction_type: 'technical_reversal'
      }
      req.reverse_merge!(attrs)

      api_call 'technical-reversal', req
    end

    # m = InfoSwitch::Mocks.new
    #
    # No DCC because of card:
    #   InfoSwitch::PosApi.new.prepare(m.dcc_prepare(m.magstripe_online_pin_purchase))
    # No DCC because of kind of API request:
    #   InfoSwitch::PosApi.new.prepare(m.no_dcc_prepare(m.dcc_magstripe_purchase))
    # DCC:
    #   purchase_req = m.dcc_magstripe_purchase
    #   prepare_resp = InfoSwitch::PosApi.new.prepare(m.dcc_prepare(purchase_req))
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.dcc_authorize_or_purchase(prepare_resp, purchase_req))
    def prepare attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,

        transaction_type: 'prepare'
      }
      req.reverse_merge!(attrs)

      api_call 'prepare-transaction', req
    end

    # m = InfoSwitch::Mocks.new
    # InfoSwitch::PosApi.new.configure_terminal(m.configure_terminal)
    def configure_terminal attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
      }
      req.reverse_merge!(attrs)

      api_call 'configure-terminal', req
    end

    # m = InfoSwitch::Mocks.new
    # Mismatch:
    #   InfoSwitch::PosApi.new.close_day(m.close_day(0))
    # Mismatch & Approved:
    #   resp = InfoSwitch::PosApi.new.close_day(m.close_day(0))
    #   InfoSwitch::PosApi.new.close_day(m.close_day(resp['batch_id'].to_i + 1))
    # Mismatch & Approved with a transaction
    #   resp = InfoSwitch::PosApi.new.close_day(m.close_day(0))
    #   InfoSwitch::PosApi.new.authorize_or_purchase(m.emv_purchase)
    #   InfoSwitch::PosApi.new.close_day(m.close_day(resp['batch_id'].to_i + 1).merge(purchase_amount: 10001, purchase_count: 1))
    def close_day attrs
      attrs = secure_attrs(attrs)

      req = {
        random: SecureRandom.base64,
      }
      req.reverse_merge!(attrs)

      api_call 'close-day', req
    end

    private

    def secure_attrs attrs
      @stringified_passthrough_fields ||= PASSTHROUGH_FIELDS.map(&:to_s)
      (attrs.try(:stringify_keys) || {}).slice(*@stringified_passthrough_fields).symbolize_keys
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
        except(:__secret).
        merge(authenticity_token: request[:__authenticity_token]).
        reject{|k,v| v.nil?}.
        to_json

      LOGGER.debug "REQUEST: #{pci_mask(raw_request, request)}"

      path = "/api/v1.0/#{function}"
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
      LOGGER.debug "RESPONSE: #{http_response.body}"

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
