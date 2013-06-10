require 'simplecov'

SimpleCov.start

require 'rspec'

RSpec.configure do |c|
  c.mock_with :rspec
end