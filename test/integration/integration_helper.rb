require "./test/test_helper"
require "rack/test"

# load SimpleRodaContext to emulate roda req/resp
require './models/simple_roda_context'

APP = Rack::Builder.parse_file('config.ru').first
USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.56 Safari/536.5'

# do not log sql
DB.loggers = []

# load settings
Setting.dataset.delete
puts '  => loading settings from dev.settings.json'
Setting.serializer file_path: './test/fixtures', file_name: 'settings.json', primary_key: :name
Setting.save_to_db_from_file!

# faster signup/login
BCrypt::Engine.cost = 1

class Test < Minitest::Test
  include Rack::Test::Methods

  def app
    APP
  end

  def setup
    # set headers
    header "User-Agent", USER_AGENT
    header "Content-Type", "application/json"
    super
  end

  # we need SimpleRodaContext to create admin from inside because there is no admin to create admin :)
  def create_admin(attrs = {})
    context = SimpleRodaContext.new({first_name: "pero", last_name: "peric", superuser: true, email: "pero@webteh.us", phone: "12345678"}.merge(attrs))
    CreateAdmin.call(context)
    admin = Admin.where(email: context.params[:email]).first
    admin = ActivateAccount.call(SimpleRodaContext.new(token: admin.activation_token, password: 'qwe123!Q'))
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

  def ok?(verb, path, payload)
    send(verb, path, payload)
    # puts last_response.inspect
    assert last_response.ok?, 'should be 200 ok'
  end

  def unauthorized?(verb, path, payload)
    send(verb, path)
    assert last_response.unauthorized?, 'should be 401 unauthorized'
  end

  def forbidden?(verb, path, payload)
    send(verb, path)
    assert last_response.forbidden?, 'should be 403 forbidden'
  end

  def not_allowed?(verb, path, payload)
    send(verb, path)
    # puts last_response.inspect
    assert last_response.method_not_allowed?, 'should be 405 method not allowed'
  end
end
