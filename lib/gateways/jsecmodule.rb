module JsecModule
  def self.host
    WebPayOpts[:iso_switch_url] || 'http://localhost:8080'
  end
end

require 'faraday'
require 'json/ext'
require 'active_support/core_ext/hash/conversions'

require_relative "jsecmodule/iso_util"
require_relative "jsecmodule/crypto"
