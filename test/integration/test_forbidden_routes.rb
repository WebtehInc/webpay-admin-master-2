require_relative "integration_helper"

class TestForbiddenRoutes < Test

  # 403 forbidden - authorize! must be called in routing tree before this route
  def test_forbidden_routes

    get  "/operators", {}.to_json
    assert last_response.unauthorized?

    admin = create_admin
    login_admin admin

    # cant see operators list without otp
    get  "/operators", {}.to_json
    assert last_response.forbidden?

    authorize_with_otp

    # now its visible
    get  "/operators", {}.to_json
    assert last_response.ok?
  end

end
