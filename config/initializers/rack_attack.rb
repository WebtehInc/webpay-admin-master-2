require 'rack/attack'

# Configure cache store (Redis)
Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(
  Redis.new(url: ENV['REDIS_URL'])
)

# ================================================
# THROTTLING (Rate Limiting)
# ================================================

# Throttle login attempts by IP address
# Limit: 5 requests per 15 minutes
Rack::Attack.throttle("login/ip", limit: 5, period: 15.minutes) do |req|
  if req.path == "/login" && req.post?
    req.ip
  end
end

# Throttle login attempts by email address
# Limit: 5 requests per 15 minutes
Rack::Attack.throttle("login/email", limit: 5, period: 15.minutes) do |req|
  if req.path == "/login" && req.post?
    # Extract email from request body (JSON)
    begin
      body = JSON.parse(req.body.read)
      req.body.rewind
      body['email'].to_s.downcase.presence
    rescue
      nil
    end
  end
end

# ================================================
# BANNING (Automatic IP Bans)
# ================================================

# Ban IPs that make too many failed login attempts
# 10 failures in 10 minutes = 1 hour ban
Rack::Attack.blocklist("block-failed-logins") do |req|
  if req.path == "/login" && req.post?
    Rack::Attack::Allow2Ban.filter(
      "login-#{req.ip}",
      maxretry: 10,
      findtime: 10.minutes,
      bantime: 1.hour
    ) do
      # Only count failed login attempts
      # This requires checking response status in middleware
      # For now, we track all login attempts
      true
    end
  end
end

# ================================================
# RESPONSE CUSTOMIZATION
# ================================================

# Custom response for throttled requests
Rack::Attack.throttled_responder = lambda do |env|
  match_data = env['rack.attack.match_data']
  now = match_data[:epoch_time]

  headers = {
    'Content-Type' => 'application/json',
    'X-RateLimit-Limit' => match_data[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
    'Retry-After' => match_data[:period].to_s
  }

  body = {
    error: 'Rate limit exceeded',
    message: 'Too many login attempts. Please try again later.',
    retry_after: match_data[:period]
  }.to_json

  [429, headers, [body]]
end

# Custom response for banned requests
Rack::Attack.blocklisted_responder = lambda do |env|
  [
    403,
    { 'Content-Type' => 'application/json' },
    [{
      error: 'Forbidden',
      message: 'Your IP has been temporarily banned due to too many failed login attempts.'
    }.to_json]
  ]
end

# ================================================
# LOGGING
# ================================================

ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
  req = payload[:request]

  if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
    puts "[Rack::Attack] #{req.env['rack.attack.match_type']}: #{req.ip} - #{req.path}"
  end
end
