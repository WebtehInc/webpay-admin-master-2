require_relative "../integration_helper"

class TestPrivateRoutes < Test

  # 401 unauthorized - authenticate! must be called in routing tree before this route
  def test_private_routes
    # logout is accessible for each admin group
    post '/logout'
    assert last_response.unauthorized? # 401
  end

end
