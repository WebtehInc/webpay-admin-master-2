unless ENV['WP_ENV'] == 'development'
  puts; puts "WP_ENV must be set to development"; puts
  exit
end

require './webpay_admin'
require "rack/test"
require "minitest/autorun"

APP = Rack::Builder.parse_file('config.ru').first
USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.56 Safari/536.5'
# DB.loggers = []

class Demo < Minitest::Test
  include Rack::Test::Methods

  def app
    APP
  end

  def setup
    DB[:audits].exclude(user_id: nil).delete
    DB[:login_trails].delete
    DB[:admins].delete

    # set headers
    header "User-Agent", USER_AGENT
    header "Content-Type", "application/json"
  end

  def login_admin(attrs = {})
    post '/login', {email: "pero@webteh.us", password: "qwe123!Q"}.merge(attrs).to_json
    header "Authorization", "Bearer #{JSON.parse(last_response.body)['token']}"
  end

  def authorize_with_otp(admin = nil)
    admin = Admin.first unless admin
    totp = ROTP::TOTP.new(admin[:otp_code])
    post '/verify-otp', {otp: totp.now}.to_json
  end

end

ADMINS = []  << %w(didier.becker@psbbanknv.com Didier Becker 11111) \
             << %w(ryjairo.kleinmoedig@gmail.com Ryjairo Kleinmoedig 22222) \
             << %w(igor@webteh.us Igor Grcman 33333) \
             << %w(damir@webteh.us Damir Roso 44444) \
             << %w(borna@webteh.us Borna Novak 55555)

class AddAdmins < Demo

  def test_add_admins

    ADMINS.each do |a|
      admin = CreateAdmin.call(email: a[0], first_name: a[1].capitalize, last_name: a[2].capitalize,
                          password: 'qwe123!Q', phone: "12345678")
    end

    puts "Records imported: #{Admin.count}"
  end

end



