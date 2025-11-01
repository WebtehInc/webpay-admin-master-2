require_relative "../integration_helper"

class TestCreateAdminAndLogin < Test

  def test_successful_signup

    # create new admin
    context = SimpleRodaContext.new first_name: "pero", last_name: "peric", superuser: true, email: "pero@webteh.us", phone: "12345678"
    CreateAdmin.call(context)

    assert_equal 1, Admin.count

    # admin is not active
    admin = Admin.first
    assert_equal false, admin.active

    # decline login
    post '/login', '{"email":"pero@webteh.us","password":"qwe123!Q"}'
    assert last_response.unprocessable?
    assert_equal 'Your account is not active', JSON.parse(last_response.body)['message']['title']

    # activation page
    get "activate-account/#{admin.activation_token}"
    assert last_response.ok?
    assert_equal 3, JSON.parse(last_response.body).keys.size # returns 3 keys - email, first_name, last_name

    # activation form
    post "activate-account/#{admin.activation_token}", {token: admin.activation_token, password: 'qwe123!Q'}.to_json
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal ['admin', 'permissions', 'spa_file_name', 'token'], resp.keys # returns {admin: {}, token: abcd ...}

    # admin is active and has related records
    admin = Admin.first
    assert_equal nil, admin.activation_token
    assert_equal true, admin.active
    assert_equal 1, admin.login_trails.count
    login_trail = LoginTrail.last
    assert_equal '127.0.0.1', login_trail[:ip]
    assert_equal 'Chrome', login_trail[:browser_name]

    header "Authorization", "Bearer #{resp['token']}"

    # get constants
    get '/constants'
    assert last_response.ok?

    # logout
    post '/logout'
    assert last_response.ok?

    # login now
    login_admin
    assert last_response.ok?
    assert_equal 2, LoginTrail.count
  end

  def test_expired_password
    old_password = "qwe123!Q" # default from helper
    new_password = "NewPass.2"
    new_password_3 = "NewPass.3"
    new_password_4 = "NewPass.4"
    new_password_5 = "NewPass.5"

    # new active admin
    admin = create_admin

    # login
    login_admin
    assert_equal 1, LoginTrail.count

    # logout
    post '/logout'
    assert last_response.ok?

    # password has expired!
    admin.update password_expiration_date: Time.now - 3600 * 24 * 10 # 10 days in the past

    # failed login for expired password
    login_admin
    assert last_response.unprocessable?
    assert_equal 'Your password has expired', JSON.parse(last_response.body)['message']['title']

    # forgot password link
    post '/reset-password', {email: admin.email}.to_json
    assert last_response.ok?

    # new token for reset
    assert admin.reload.reset_password_token

    # reset password failed with old password
    post "/reset-password/#{admin.reset_password_token}", {password: old_password}.to_json
    assert last_response.unprocessable?
    assert_equal 'should be different from previous four passwords', JSON.parse(last_response.body)['password'][0]

    # reset password sucess with new password
    post "/reset-password/#{admin.reset_password_token}", {password: new_password}.to_json
    assert last_response.ok?
    assert_equal 2, LoginTrail.count # auto login

    # sucessful login
    login_admin password: new_password
    assert last_response.ok?
    assert_equal 3, LoginTrail.count

    ### reset password multiple times time to build history

    # reset password 2nd time to add 3rd pass to history
    post '/reset-password', {email: admin.email}.to_json
    post "/reset-password/#{admin.reload.reset_password_token}", {password: new_password_3}.to_json
    assert last_response.ok?

    # reset password 3rd time to add 4th pass to history
    post '/reset-password', {email: admin.email}.to_json
    post "/reset-password/#{admin.reload.reset_password_token}", {password: new_password_4}.to_json
    assert last_response.ok?

    ### history now is [old, new, pass 3, pass 4], all should fail
    post '/reset-password', {email: admin.email}.to_json

    # fail old
    post "/reset-password/#{admin.reload.reset_password_token}", {password: old_password}.to_json
    assert last_response.unprocessable?

    # fail new
    post "/reset-password/#{admin.reset_password_token}", {password: new_password}.to_json
    assert last_response.unprocessable?

    # fail 3rd
    post "/reset-password/#{admin.reset_password_token}", {password: new_password_3}.to_json
    assert last_response.unprocessable?

    # fail 4th
    post "/reset-password/#{admin.reset_password_token}", {password: new_password_4}.to_json
    assert last_response.unprocessable?

    # 5th will be accepted
    post "/reset-password/#{admin.reset_password_token}", {password: new_password_5}.to_json
    assert last_response.ok?
    assert_equal 6, LoginTrail.count
  end

  def test_failed_logins
    # no payload
    post '/login'
    assert last_response.not_found?

    create_admin

    # fail login for 3 times
    post '/login', '{"email":"pero@webteh.us","password":"invalid"}'
    post '/login', '{"email":"pero@webteh.us","password":"invalid"}'
    post '/login', '{"email":"pero@webteh.us","password":"invalid"}'

    # disabled login after 3 tries
    admin = Admin.first
    assert_equal 3, admin[:failed_login_count]
    post '/login', '{"email":"pero@webteh.us","password":"qwe123!Q"}'
    assert last_response.forbidden?
    assert_equal 'To many failed login attempts', JSON.parse(last_response.body)['message']['title']

    # disabled login after failed_login_leeway - 5 sec has passed
    Admin.update_without_audit(admin[:id], last_login_attempt_at: (admin[:last_login_attempt_at] - WebPayAdmin.opts[:failed_login_leeway] + 5))
    post '/login', '{"email":"pero@webteh.us","password":"qwe123!Q"}'
    assert last_response.forbidden?

    # enabled login after failed_login_leeway + 5 sec has passed
    Admin.update_without_audit(admin[:id], last_login_attempt_at: (admin[:last_login_attempt_at] - WebPayAdmin.opts[:failed_login_leeway] - 5))
    post '/login', '{"email":"pero@webteh.us","password":"qwe123!Q"}'
    assert last_response.ok?
    assert_equal 0, Admin.first[:failed_login_count]
  end

end
