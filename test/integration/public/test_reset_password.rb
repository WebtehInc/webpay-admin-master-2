require_relative "../integration_helper"

class TestResetPassword < Test

  def test_reset_password

    # create new admin
    context = SimpleRodaContext.new first_name: "pero", last_name: "peric", superuser: true, email: "pero@webteh.us", phone: "12345678"
    CreateAdmin.call(context)

    assert_equal 1, Admin.count

    # admin is not active
    admin = Admin.first
    assert_equal false, admin.active

    admin = Admin.first

    # activate
    post "/activate-account/#{admin.activation_token}",  {token: admin.activation_token, password: 'qwe123!Q'}.to_json
    assert last_response.ok?

    # reset password
    # invalid email
    post '/reset-password', {email: "invalid@webteh.us"}.to_json
    assert last_response.ok? # do not reveal non existing emails

    # valid email
    post '/reset-password', {email: "pero@webteh.us"}.to_json
    assert last_response.ok?
    assert_equal 'password reset done', JSON.parse(last_response.body)['message']

    admin.reload
    assert admin.reset_password_token # token is generated

    # get admin for reset info
    get "/reset-password/#{admin.reset_password_token}"
    assert last_response.ok?
    resp = JSON.parse(last_response.body)
    assert_equal Admin::PUBLIC_ATTRS.size, resp.keys.size # print all public attrs
    assert_equal admin.first_name, resp['first_name']     # we print admin info when changing password

    post "/reset-password/#{admin.reset_password_token}", {}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size # 1 errors
    assert resp['password'] # password error, must be filled and strong

  end

end
