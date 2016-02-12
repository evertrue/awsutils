require 'simplecov'

SimpleCov.start

require 'rspec'

RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
end
