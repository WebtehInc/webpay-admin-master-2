require "jwt"

module Jwt
  def self.generate_token(app, admin_id)
    exp = Time.now.to_i + app.opts[:jwt_ttl]
    payload = { :admin_id => admin_id, :exp => exp }
    token = JWT.encode payload, app.opts[:jwt_hmac_secret], app.opts[:jwt_algorithm]
  end

  def self.decode_token(app, encoded_token)
    decoded_token = JWT.decode encoded_token, app.opts[:jwt_hmac_secret], true,
                               { :leeway => app.opts[:jwt_leeway], :algorithm => app.opts[:jwt_algorithm] }
  rescue #Jwt::DecodeError #ExpiredSignature
    puts "Jwt => Jwt::DecodeError or ExpiredSignature ..."
    false
  end

  module InstanceMethods
    attr_accessor :admin_id

    def send_token!(admin_id, payload = {})
      token_payload = { token: Jwt.generate_token(self, admin_id) }
      puts "Jwt => sending payload with token ..."
      render_success(payload.merge(token_payload))
    end

    # login
    def authenticate!
      if env["HTTP_AUTHORIZATION"]
        encoded_token = env["HTTP_AUTHORIZATION"].split(" ").last
        if decoded_token = Jwt.decode_token(self, encoded_token)
          self.admin_id = decoded_token[0]["admin_id"]
          puts "Jwt => token ok for admin_id: #{admin_id} ..."
          return # pass to next route
        else
          puts msg = "Jwt => token is expired or invalid ..."
          render_unauthorized([msg])
        end
      else
        puts msg = "Jwt => token is missing ..."
        render_unauthorized([msg])
      end
    end

    # tfa
    def authorize!
      # ArgumentError: key cannot be blank is raised if dalli key is nil or empty string
      render_forbidden(error = { otp: "pending" }) unless MEMORY_STORE.get(Admin.find_value_by_attrs(:otp_code, id: admin_id) || "no_key")
    end

    # input ok
    def render_success(success = {})
      response.write success.to_json
      response.status = 200
      request.halt
    end

    # invalid input
    def render_error(error = {}, status = 422)
      # BUG: dry-validation returns second error msg even if its not triggered ie. {attr: [err1, err2 ..]}, print only first one - {attr: [err1]}
      error_with_single_values = error.reduce({}) { |m, (k, v)| m.update k => (v.class == Array ? [v[0]] : v) }
      puts "VALIDATION ERROR: #{error_with_single_values.inspect}"
      response.status = status
      response.write error.to_json
      request.halt # stop routing
    end

    # invalid login
    def render_unauthorized(error = {})
      response.status = 401
      response.write error.to_json
      request.halt
    end

    # invalid tfa
    def render_forbidden(error = {})
      response.status = 403
      response.write error.to_json
      request.halt
    end

    # not enough privileges
    def render_not_allowed(error = {})
      response.status = 405
      response.write error.to_json
      request.halt
    end
  end
end

Roda.plugin Jwt
