module JsecModule
  module IsoUtil

    def force_length obj, length
      if obj.is_a?(String)
        obj.ljust(length)[0...length]
      elsif obj.is_a?(Integer)
        obj.to_s.rjust(length, '0')[0...length]
      else
        puts caller.join("\n")
        raise RuntimeError, "unknown object class #{obj.class} of '#{obj.inspect}'"
      end
    end

    def to_date date
      if date.is_a? String
        DateTime.parse date
      else # date is a Date
        date
      end
    end

    def to_hex bytes
      bytes.unpack('H*').first
    end

    def from_hex hex
      [hex].pack('H*')
    end

    def to_bitmap bytes
      bytes.unpack('b*').first
    end

    def from_bitmap bitmap
      [bitmap].pack('b*')
    end

    def to_base64(arg)
      arg ? Base64.encode64(arg.to_s) : nil
    end

    def from_base64(arg)
      arg ? Base64.decode64(arg.to_s) : nil
    end


    extend self
  end
end