require 'rubygems'
require 'fog'
require 'optimist'
require 'json'

module AwsUtils
  class Route53ListResourceRecord
    def connection
      @connection ||= Fog::DNS::AWS.new
    end # def connection

    def parse_opts
      opts = Optimist.options do
        opt :format, 'Output format', default: 'table'
      end
      opts[:name] = ARGV.last
      opts
    end # def parse_opts( args )

    def zone
      @zone ||= connection.zones.all('domain' => zone_name).first
    end

    def zone_name
      @zone_name ||= @opts[:name].split('.')[-2..-1].join('.') + '.'
    end

    def apex?
      @opts[:name].split('.')[-3].nil? ? true : false
    end

    def initialize
      @opts = parse_opts
    end # def initialize( args )

    def display_record(record)
      if @opts[:format] == 'json'
        puts JSON.pretty_generate(zone_to_json([record]).first)
      else
        puts 'Name: ' + record.name
        puts 'Type: ' + record.type
        puts 'TTL: ' + record.ttl
        puts record.value.count < 2 ? 'Value:' : 'Values:'
        record.value.each { |rr| puts "  #{rr}" }
      end
    end

    def record_by_name
      name = @opts[:name].split('.').join('.') + '.'
      zone.records.find { |r| r.name == name }
    end

    def zone_to_json(zone_records)
      zone_records.map do |r|
        {
          'name' => r.name,
          'type' => r.type,
          'ttl' => r.ttl,
          'value' => r.value
        }
      end
    end

    def print_table
      zone.records.each do |r|
        printf(
          "%-40s%-8s%-8s%-40s\n",
          r.name,
          r.type,
          r.ttl,
          r.value.join(' ')
        )
      end
    end

    def list_all
      if @opts[:format] == 'json'
        puts JSON.pretty_generate(zone_to_json(zone.records))
      else
        print_table
      end
    end

    def run
      if apex?
        list_all
      else
        display_record(record_by_name)
      end
    end
  end # class Route53AddResourceRecord
end # module AwsUtils
