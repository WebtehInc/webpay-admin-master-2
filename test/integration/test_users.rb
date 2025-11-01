require_relative "integration_helper"

class TestUsers < Test

  def test_add_bank_account

    admin = create_admin
    login_admin
    authorize_with_otp

    user = generate_user
    account_number = '12345678'

    # no payload
    post "/users/#{user.id}/add-bank-account", {}.to_json
    assert last_response.unprocessable?
    assert_equal 2, JSON.parse(last_response.body).keys.size

    # add account
    post "/users/#{user.id}/add-bank-account", {account_number: account_number, type: 'current'}.to_json
    assert last_response.ok?

    # account_number already taken
    post "/users/#{user.id}/add-bank-account", {account_number: account_number, type: 'current'}.to_json
    assert last_response.unprocessable?
    resp = JSON.parse(last_response.body)
    assert_equal 1, resp.keys.size
    assert resp['account_number']

    # attrs
    account = Account.first
    refute account.active
    assert_equal 'pending', account.state

    # counts
    assert_equal 1, Account.count
    assert_equal 3, Audit.count

    # relations
    assert_equal 1, user.accounts.count
    assert_equal 1, Account.first.users.count
    assert_equal 3, admin.changes.count

  end

end
