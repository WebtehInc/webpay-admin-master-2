require_relative 'init_nfc_writer'
require_relative 'configure_nfc_writer'
require_relative 'prepare_nfc_writer_init_data'

class NFCWriter

  def self.api_keys access_token
    InfoSwitch.api_keys 'NFCWriter', access_token
  end

end
