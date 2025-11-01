require 'useragent'

class LoginTrail < Sequel::Model
  many_to_one :user

  def self.insert(admin_id, context)
    ip = context.env['HTTP_X_FORWARDED_FOR'] || context.env['REMOTE_ADDR']
    user_agent = UserAgent.parse(context.env['HTTP_USER_AGENT'])

    self.create admin_id: admin_id, ip: ip, user_agent: context.env['HTTP_USER_AGENT'],
                browser_name: user_agent.browser, browser_version: user_agent.version,
                platform: user_agent.platform
  end
end
