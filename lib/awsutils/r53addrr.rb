require 'rubygems'
require 'fog'
require 'optimist'

module AwsUtils
  class Route53AddResourceRecord
    def connection
      @connection ||= Fog::DNS::AWS.new
    end

    def parse_opts
      Optimist.options do
        opt :name, 'The name', short: 'n', type: String, required: true
        opt :type, 'Record type (e.g. CNAME or A)', short: 'T', type: String, required: true
        opt :ttl, 'Time-to-live', short: 't', type: String, default: '300'
        opt :value, 'Record Value', short: 'v', type: String, required: true
      end
    end

    def initialize
      @opts = parse_opts
    end
  end
end
