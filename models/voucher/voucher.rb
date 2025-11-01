class Voucher < Sequel::Model

  unrestrict_primary_key

  many_to_one :operator, key: :operator_code
  many_to_one :product

  many_to_one :terminal
  many_to_one :observer, key: :observed_by, class: :Admin

  one_to_many :transactions # auth, void ...

  # PUBLIC_ATTRS = [:id]
  #
  # def public_values
  #   values.select{|k,v| PUBLIC_ATTRS.include?(k)}
  # end

  # returns a hash of decrypted sensitive data, this is the general pattern because the Trx model for example encrypts
  # multiple values - track1, track2, track3, emv_data, pan - to name a few and multiple round trips to the crypto card
  # are not desirable
  #
  # the Gateway::Crypto#decrypt and Gateway::Crypto#encrypt calls can accept an array of arguments for batch encryption
  # and decryption, so this is the general pattern to access the data:
  def decrypted_sensitive_data
    @decrypted_sensitive_data ||= begin
      rv = crypto.decrypt [value]
      {
        value: rv[0],
        key_label: crypto.default_data_key_label
      }
    end
  end

  # returns a hash of cryptograms, same pattern as for decryption, make sure to store crypto.default_data_key_label into
  # :default_key_label
  def encrypted_sensitive_data attributes
    value = attributes[:value]

    rv = crypto.encrypt [value]
    {
      value: rv[0],
      key_label: crypto.default_data_key_label
    }
  end



  private

  def crypto
    @crypto ||= begin
      rv = WebPayAdmin.opts[:crypto_client].new
      rv.default_data_key_label = default_key_label if default_key_label
      rv
    end
  end

end
