class Object
  def try(m, *args, &block)
    if is_a?(NilClass)
      self
    else
      send(m, *args, &block)
    end
  end
end

class Hash
  def slice *keys
    select{|k| keys.member?(k)}
  end

  def except *keys
    reject{|k| keys.member?(k)}
  end

  def deep_symbolize_keys
    reduce({}){|memo,(k,v)| memo[k.to_sym] = v.deep_symbolize_keys; memo}
  end
end

class Array
  def stringify
    reduce([]){|a,t| a << t.to_s}
  end
end

module Utils
  # for filtering sensitive data in hashes
  def self.shallow_hash_filter(h, *args)
    default_sensitive_attrs = ['password', 'token', 'digest', 'otp', 'image', 'file', 'data']
    sensitive_attrs = (default_sensitive_attrs + args).flatten
    r = h.dup
    r.each do |k,v|
      if sensitive_attrs.include?(k.to_s)
        r[k] = '[filtered]'
      else
        r[k] = v
      end
    end
  end

  def self.generate_random_token
    ROTP::Base32.random_base32
  end

  def self.error_handler(e, context)
    time_spent = Time.now - context.instance_variable_get(:@start_time)
    Mailer.sendmail("/app/exception", e, context, time_spent)
    event_hash = {
      type: 'exception', title: "[#{time_spent} sec] #{e.class}: #{e.message[0..255]}", body: e.backtrace,
      params: self.shallow_hash_filter(context.request.params),
      env: self.shallow_hash_filter(context.env, 'roda.json_params')
    }
    Event.create(event_hash)
    LOGGER.error "APP ERROR:\n"
    LOGGER.error event_hash[:title]
    LOGGER.error event_hash[:body].join("\n")
    LOGGER.error self.format_hash[event_hash[:params]]
    LOGGER.error self.format_hash[event_hash[:env]]
  end

  def self.format_hash
    lambda{|h| h.map{|k, v| "#{k.inspect} => #{v.inspect}"}.sort.join("\n")}
  end

  def self.random_pin(size)
    ('0' * size + rand(('9' * size).to_i).to_s)[-size..-1]
  end

  def self.translit(str)
    str.tr( "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
            "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz")
  end

  def self.to_money(int)
    "%.2f" % (int / 100.0).to_s
  end

end
