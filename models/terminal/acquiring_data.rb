module AcquiringData
  class TerminalData < DStruct::DStruct

    attributes  strings:  [:load_balancer, :default_acquirer_logid, :installment_options, :location_indicator, :terminal_status],
                booleans: [:attended]

    def self.call(id, context)
      terminal = Terminal[id]
      terminal_data = new(context.params)

      merchant_validation_schema = Dry::Validation.Form do
        configure do
          config.predicates = SchemaPredicates
          config.messages_file = Pathname(__dir__).join('../errors.yml')
        end
        key(:load_balancer)           { inclusion?(ACQUIRING_DATA_SETTINGS[:load_balancers].keys) }
        key(:default_acquirer_logid)  { inclusion?(ACQUIRING_DATA_SETTINGS[:acquirer_logids].keys) }
        key(:installment_options)     { inclusion?(ACQUIRING_DATA_SETTINGS[:installment_options].keys) }
        key(:location_indicator)      { inclusion?(ACQUIRING_DATA_SETTINGS[:location_indicators].keys) }
        key(:terminal_status)         { inclusion?(ACQUIRING_DATA_SETTINGS[:terminal_statuses].keys) }
        key(:attended)                { bool? }
      end

      terminal_data.add_validation_schema merchant_validation_schema

      if terminal_data.valid?
        terminal_data.to_h.merge!(
          authenticity_token: "Terminal:#{terminal.access_token}",
          debug: false,
          name: "Terminal #{terminal.access_token}",
          tid: terminal.access_token,
          mid: 'Terminal',
          random: SecureRandom.uuid,
          secret: SecureRandom.uuid
        )

        # first call for validation
        resp = InfoSwitch::TerminalApi.new.create_or_update_terminal(**terminal_data.to_h)

        context.render_success(resp.except('secret'))
      else
        context.render_error(terminal_data.errors)
      end
    end
  end

  class AccountData < DStruct::DStruct

    attributes strings: [:name, :mid, :tid, :city, :address, :country, :postal_code, :mcc, :acquirer_logid, :tacq_status]

    def self.call(id, account_id, context)
      terminal = Terminal[id]
      account_data = new(context.params)

      account_validation_schema = Dry::Validation.Form do
        configure do
          config.predicates = SchemaPredicates
          config.messages_file = Pathname(__dir__).join('../errors.yml')
        end
        key(:name)            { filled? & size?(2..60) }
        key(:tid)             { filled? & size?(2..60) }
        key(:mid)             { filled? & size?(2..60) }
        key(:city)            { filled? & size?(2..60) }
        key(:address)         { filled? & size?(2..60) }
        key(:country)         { filled? & size?(2..60) }
        key(:postal_code)     { filled? & size?(2..60) }
        key(:mcc)             { filled? & size?(2..60) }
        key(:acquirer_logid)  { inclusion?(ACQUIRING_DATA_SETTINGS[:acquirer_logids].keys) }
        key(:tacq_status)     { inclusion?(ACQUIRING_DATA_SETTINGS[:tacq_statuses].keys) }
      end

      account_data.add_validation_schema account_validation_schema

      if account_data.valid?
        # get terminal data
        terminal_data = InfoSwitch::TerminalApi.new.show_terminal(authenticity_token: "Terminal:#{terminal.access_token}")
        terminal_data = terminal_data.deep_symbolize_keys

        # set requireds fileds not returned in show_terminal
        terminal_data[:name] = "Terminal #{terminal.access_token}"
        terminal_data[:tid] = terminal.access_token
        terminal_data[:mid] = 'Terminal'
        terminal_data[:location_indicator] = 'merchant' unless terminal_data[:location_indicator]

        # set tacq
        tacq_key = "#{terminal.access_token}-#{account_data.acquirer_logid}".to_sym
        terminal_data[:tacqs][tacq_key] = account_data.to_h

        # update call
        resp = InfoSwitch::TerminalApi.new.create_or_update_terminal(**terminal_data.merge(secret: SecureRandom.uuid))
        context.render_success(resp.except(:secret))
      else
        context.render_error(account_data.errors)
      end
    end
  end
end
