require 'rubygems'
require 'fog'
require 'optimist'

module AwsUtils

  class Route53AddResourceRecord

    def connection
      @connection ||= Fog::DNS::AWS.new
    end # def connection

    def parse_opts
      opts = Optimist::options do
        opt :name, "The name", :short => 'n', :type => String, :required => true
        opt :type, "Record type (e.g. CNAME or A)", :short => 'T', :type => String, :required => true
        opt :ttl, "Time-to-live", :short => 't', :type => String, :default => "300"
        opt :value, "Record Value", :short => 'v', :type => String, :required => true
      end # opts = Optimist::options
    end # def parse_opts

    def initialize
      @opts = parse_opts
    end # def initialize

  end # class Route53AddResourceRecord

end # module AwsUtils
