module Importers
  class ResolveTimeForCronReports
    include Functional
    include ValidationRaisable

    def call env, _options = {}
      days_ago = Time.now - env['MERCHANT_REPORTS_DAYS_AGO'].to_i * 24*60*60 if env['MERCHANT_REPORTS_DAYS_AGO']
      date = Time.parse(env['MERCHANT_REPORTS_DATE']) if env['MERCHANT_REPORTS_DATE']

      days_ago || date || validation_error("please set MERCHANT_REPORTS_DAYS_AGO or MERCHANT_REPORTS_DATE")
    end
  end
end