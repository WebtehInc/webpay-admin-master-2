# set MEMORY_STORE as memcached client
require 'dalli'
begin
  puts "* Setting MEMORY_STORE as memcached client"
  MEMORY_STORE = Dalli::Client.new(ENV['MEMCACHED_URL'] || 'localhost:11211', :namespace => 'webpay', :compress => true, :expires_in => 5*30)
  MEMORY_STORE.set('test', true)
rescue
  puts 'ERROR: Memcached client is not runing.'
  exit
end

MemoryStore = MEMORY_STORE
