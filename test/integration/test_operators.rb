require_relative "integration_helper"

class TestOperators < Test
  def test_generate_api_key
    operator = generate_operator(code: "ae")
    path = "/operators/ae/generate-api-key"
    admin = create_admin

    # not public route
    post path, {}.to_json
    assert last_response.unauthorized?

    login_admin

    # new key
    post path, {}.to_json
    resp = JSON.parse(last_response.body)
    assert last_response.ok?
    assert resp["operator"]
    assert_equal 40, resp["api_key"].size
  end
end
