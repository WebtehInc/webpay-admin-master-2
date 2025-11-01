require_relative "integration_helper"

class TestCustomers < Test

  def test_add_customer

    operator    = generate_operator(code: 'ae', type: 'bill', currency: 'USD')
    operator2   = generate_operator(code: 'ae2', type: 'bill', currency: 'USD')
    number      = 12345
    admin       = create_admin(superuser: false)
    balance     = 67890

    # not public route
    post "/operators/add-customer", {}.to_json
    assert last_response.unauthorized?

    login_admin

    # no permission
    post "/operators/add-customer", {}.to_json
    assert last_response.method_not_allowed?

    # add permission
    role = Role.create(name: 'Customer operator', description: '...')
    permission = Permission.create(context: 'operators', action: 'add-customer')
    role.add_admin admin
    role.add_permission permission

    # permission ok but no otp
    post "/operators/add-customer", {}.to_json
    assert last_response.forbidden?

    authorize_with_otp

    # no payload
    post "/operators/add-customer", {}.to_json
    assert last_response.unprocessable?
    assert_equal 3, JSON.parse(last_response.body).keys.size


    # invalid operator_code
    post "/operators/add-customer", {number: number, operator_code: 'xx', balance: balance}.to_json
    assert last_response.unprocessable?
    assert_equal 'unknown or disabled operator', JSON.parse(last_response.body)['operator_code'][0]

    # input ok
    post "/operators/add-customer", {number: number, operator_code: operator.code, balance: balance}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.ok?

    # check db
    assert_equal 1, Customer.count
    assert_equal 1, Audit.count

    customer = Customer.first
    assert_equal number.to_s, customer.number
    assert_equal operator.code, customer.operator_code
    assert_equal balance, customer.balance

    # existing customer for same operator
    post "/operators/add-customer", {number: number, operator_code: operator.code, balance: balance}.to_json
    assert last_response.unprocessable?
    assert_equal 'has already been taken', JSON.parse(last_response.body)['number'][0]

    # new customer for other operator
    post "/operators/add-customer", {number: number, operator_code: operator2.code, balance: balance}.to_json
    assert last_response.ok?
    assert_equal 2, Customer.count
  end

end
