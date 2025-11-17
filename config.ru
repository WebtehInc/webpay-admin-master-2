require 'rack'
require 'rack/cors'

# load env settings from file
require 'dotenv'
Dotenv.load

# RATE LIMITING - MUST BE LOADED BEFORE APP
require_relative 'config/initializers/rack_attack'
use Rack::Attack

# set secure headers
require_relative "secure_headers"
use Rack::SecureHeaders

# set CORS
use Rack::Cors do
  allow do
    origins ENV["WP_SPA_HOST_URL"].chomp('#').chomp('/').to_s
    resource '*', :headers => :any, :methods => [:get, :post, :options, :put, :patch], :expose  => ['X-total-count', 'X-per-page']
  end
end

# set assets
use Rack::Static, :urls => ['/favicon.ico', '/static', '/icons.svg'], :root => 'public'
use Rack::Static, :urls => ['/uploads'], :root => ENV['UPLOADS_ROOT_FROM_WEBPAY']
use Rack::Static, :urls => {"/" => 'index.html'}, :root => 'public'

# set logger
LOGGER = Logger.new STDOUT

# load app
puts "* Starting webpay_admin app ..."
unless ENV["WP_ENV"]
  puts "WP_ENV is not set"
  exit
end
require_relative 'webpay_admin'

# run app
run WebPayAdmin.freeze.app
