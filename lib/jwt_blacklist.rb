# JWT Token Blacklist Service
# Uses Redis to store invalidated JWT tokens until their natural expiration
class JwtBlacklist
  # Add a token to the blacklist
  # @param token [String] The JWT token to blacklist
  # @param exp_time [Integer] Token expiration timestamp (Unix time)
  def self.add(token, exp_time)
    return false unless token && exp_time

    # Calculate TTL: time remaining until token would expire naturally
    ttl = exp_time - Time.now.to_i

    # Only blacklist if token hasn't expired yet
    return false if ttl <= 0

    # Store token in Redis with TTL matching token expiration
    # Key format: "jwt_blacklist:<token>"
    # Value: timestamp when blacklisted
    key = "jwt_blacklist:#{token}"
    $redis.setex(key, ttl, Time.now.to_i)

    puts "[JwtBlacklist] Token blacklisted for #{ttl} seconds"
    true
  rescue => e
    puts "[JwtBlacklist] Error adding token: #{e.message}"
    false
  end

  # Check if a token is blacklisted
  # @param token [String] The JWT token to check
  # @return [Boolean] true if token is blacklisted, false otherwise
  def self.blacklisted?(token)
    return false unless token

    key = "jwt_blacklist:#{token}"
    $redis.exists?(key) > 0
  rescue => e
    puts "[JwtBlacklist] Error checking token: #{e.message}"
    # Fail open: if Redis is down, allow the request
    # Token will still be validated by JWT.decode
    false
  end

  # Remove a token from the blacklist (mainly for testing)
  # @param token [String] The JWT token to remove
  def self.remove(token)
    return false unless token

    key = "jwt_blacklist:#{token}"
    $redis.del(key)
    true
  rescue => e
    puts "[JwtBlacklist] Error removing token: #{e.message}"
    false
  end

  # Get count of blacklisted tokens (for monitoring)
  # @return [Integer] Number of blacklisted tokens
  def self.count
    keys = $redis.keys("jwt_blacklist:*")
    keys.size
  rescue => e
    puts "[JwtBlacklist] Error counting tokens: #{e.message}"
    0
  end
end
