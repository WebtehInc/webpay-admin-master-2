# load env
require 'dotenv'
Dotenv.load

# load cache store
require_relative 'models/memory_cache/store'

# load app
require './webpay_admin'
