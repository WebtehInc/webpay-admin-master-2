module InfoSwitch
  class Authorizer

    def self.call *args, &block
      new.call *args, &block
    end

    def call path, raw_request, authenticity_token, secret, options = {}
      authentication_method = 'InfoSwitch-HMAC-SHA512-fixed'
      authenticity_token = authenticity_token.to_s
      random = options.delete(:random)
      digest = nil

      if random
        digest = Digest::SHA512.hexdigest build_clear_for_digest(secret, path, random)
      else
        digest = Digest::SHA512.hexdigest build_clear_for_digest(secret, path, raw_request)
      end

      [authentication_method, authenticity_token, digest, random].join(" ")
    end


    private

    def build_clear_for_digest secret, path, raw_request
      "#{secret}\n#{path}\n#{raw_request}"
    end

  end
end