module InfoSwitch

  AUTHENTICITY_TOKEN = ENV['INFOSWITCH_AUTHENTICITY_TOKEN'] || '3310ba26f3de7caa793c4e41c0537561e27a8af4c000525de9df28a6f128a22b0e6c4a882a5ffcff7d90d11075784cc5b14e6ced0a604f085082d4eafaf71310'
  SECRET = ENV['INFOSWITCH_SECRET'] || '3310ba26f3de7caa793c4e41c0537561e27a8af4c000525de9df28a6f128a22b0e6c4a882a5ffcff7d90d11075784cc5b14e6ced0a604f085082d4eafaf71310'

  class InfoSwitchError < StandardError; end

  class ApiArgumentError < InfoSwitchError; end

  def self.host
    WebPayOpts[:infoswitch_url]
  end

  def self.api_keys domain, access_token
    {
      __authenticity_token: "#{domain}:#{access_token}",
      __secret: JsecModule::Crypto.new.digest("#{domain}:#{access_token}"),
    }
  end

  def self.merchant_keys
    {
      __authenticity_token: AUTHENTICITY_TOKEN,
      __secret: SECRET
    }
  end

end


require 'pry'

require 'faraday'
require 'json/ext'
require 'active_support/core_ext/hash/conversions'

require_relative "infoswitch/mocks"
require_relative "infoswitch/authorizer"
require_relative "infoswitch/pos_api"
require_relative "infoswitch/terminal_api"
require_relative "infoswitch/mifare_api"