FEATURES = {}

if ENV['ACQUIRING'] == 'true'
  require_relative '../settings/acquiring_data.rb'
  FEATURES[:acquiring] = ACQUIRING_DATA_SETTINGS
end
