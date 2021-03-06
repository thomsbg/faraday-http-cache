require 'uri'
require 'socket'

require 'faraday-http-cache'
require 'faraday_middleware'
require 'json'

require 'support/hash_cache'
require 'support/test_app'
require 'support/test_server'

server = TestServer.new

ENV['FARADAY_SERVER'] = server.endpoint
ENV['FARADAY_ADAPTER'] ||= 'net_http'

server.start

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'

  config.after(:suite) do
    server.stop
  end
end
