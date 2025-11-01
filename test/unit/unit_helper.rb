require "./test/test_helper"

# setup DB because env file is included in roda, we use just models for speed
require 'sequel'
DB = Sequel.connect(ENV.delete('WP_TEST_DATABASE_URL'))
require 'logger'
DB.loggers << Logger.new($stdout)

require_relative "../../models"

class Test < Minitest::Test

  def setup
    super
  end

end


