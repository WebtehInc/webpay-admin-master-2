require_relative "../integration_helper"

class TestOperatorManagesAccounts < Test
  def test_manage_accounts
    operator = generate_operator(code: "ae")
    path = "/api/operators/manage-accounts"

    # invalid api key
    header "Apikey", "invalid-key"
    post path, {}.to_json
    assert last_response.not_found?
    assert_equal ({ "error" => "Operator not found" }), JSON.parse(last_response.body)

    # get api key
    create_admin
    login_admin
    post "/operators/ae/generate-api-key", {}.to_json
    api_key = JSON.parse(last_response.body)["api_key"]
    header "Apikey", api_key

    # empty payload
    post path, {}.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "number_of_accounts not found" }), JSON.parse(last_response.body)

    # invalid integer value
    post path, { number_of_accounts: "abc", sum_of_balances: 100, accounts: [] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "ArgumentError: invalid value for Integer(): \"abc\"" }), JSON.parse(last_response.body)

    # account invalid active value
    post path, { number_of_accounts: 1, sum_of_balances: 100, accounts: [{}] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "Account  does not have active value" }), JSON.parse(last_response.body)

    # account not found
    post path, { number_of_accounts: 1, sum_of_balances: 100, accounts: [{ abc: 123, active: true }] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "Account  not found" }), JSON.parse(last_response.body)

    # account not found
    post path, { number_of_accounts: 1, sum_of_balances: 100, accounts: [{ account: 123, active: true }] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "Account 123 not found" }), JSON.parse(last_response.body)

    # invalid sum_of_balances
    customer = generate_customer(number: "123456", operator_code: operator.code, balance: 200)
    post path, { number_of_accounts: 1, sum_of_balances: 100, accounts: [{ account: 123456, active: true }] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "sum_of_balances does not match, found 0, declared 100" }), JSON.parse(last_response.body)

    # invalid number_of_accounts
    post path, { number_of_accounts: 2, sum_of_balances: 123, accounts: [{ account: 123456, active: true }] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "number_of_accounts does not match, found 1, declared 2" }), JSON.parse(last_response.body)

    # invalid totals
    customer2 = generate_customer(number: "123456789", operator_code: operator.code, balance: 300, active: false)
    post path, { number_of_accounts: 2, sum_of_balances: 123, accounts: [{ account: 123456, active: true, balance: 10 }, { account: 123456789, active: true, balance: 20 }] }.to_json
    assert last_response.unprocessable?
    assert_equal ({ "error" => "sum_of_balances does not match, found 30, declared 123" }), JSON.parse(last_response.body)

    # payload ok
    post path, { number_of_accounts: 2, sum_of_balances: 30, accounts: [{ account: 123456, active: true, balance: 10 }, { account: 123456789, active: true, balance: 20 }] }.to_json
    assert last_response.ok?
    assert_equal ({ "total_updates" => 2 }), JSON.parse(last_response.body)

    customer2.reload
    assert_equal 20, customer2.balance
    assert_equal true, customer2.active
  end
end
