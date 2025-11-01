require_relative "../integration_helper"

module Importers
  class TestResolveTimeForCronReports < Test

    Resolver = Importers::ResolveTimeForCronReports

    def setup
      # do nothing
    end

    def test_normal_use
      Timecop.freeze

      assert_raises Importers::ResolveTimeForCronReports::ValidationError do
        Resolver[{}]
      end

      rv = Resolver[{'MERCHANT_REPORTS_DAYS_AGO' => 1}]
      assert_equal Time.now-24*60*60, rv, 'expectation off on MERCHANT_REPORTS_DAYS_AGO'
      rv = Resolver[{'MERCHANT_REPORTS_DAYS_AGO' => 0}]
      assert_equal Time.now, rv, 'expectation off on MERCHANT_REPORTS_DAYS_AGO when its 0'

      rv = Resolver[{'MERCHANT_REPORTS_DATE' => '20160102'}]
      assert_equal Time.new(2016, 1, 2), rv, 'expectation off on MERCHANT_REPORTS_DAYS_AGO'
    end

  end
end
