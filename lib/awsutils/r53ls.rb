require 'rubygems'
require 'fog'
require 'trollop'

module AwsUtils

  class Route53ListResourceRecord

    def connection
      @connection ||= Fog::DNS::AWS.new
    end # def connection

    def parse_opts( args )
      {:name => args[1]}
    end # def parse_opts( args )

    def zone_id
      @zone_id ||= connection.list_hosted_zones.body["HostedZones"].select {|z| z["Name"] == zone_name}.first["Id"]
    end

    def zone_name
      @zone_name ||= @opts[:name].split('.')[-2..-1].join('.') + "."
    end

    def initialize( args )
      @opts = parse_opts( args )
    end # def initialize( args )

    def zone_data
      @zone_data ||= connection.c.list_resource_record_sets(@zone_id).body
    end

    def output( record )
      puts "Name: " + record['Name']
      puts "Type: " + record['Type']
      puts "TTL: " + record['TTL']
      record["ResourceRecords"].each do |rr|
        puts "  " + rr
      end
    end

    def get_record_by_name
      name = opts[:name].split('.').join('.') + "."
      record = zone_data.select{|r| r["Name"] == name }.first
    end

    def run
      output( get_record_by_name )
    end

  end # class Route53AddResourceRecord

end # module AwsUtils
