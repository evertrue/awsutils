require 'fog/aws/elb'
require 'fog/core/parser'
require 'facets/string/titlecase'
require 'rainbow'

module AwsUtils
  class ElbLs
    attr_reader :args

    def run(args)
      @args = args

      if args.empty?
        puts connection.load_balancers.map(&:id).sort
      else
        args.each do |lb|
          puts colorize_yaml(attributes(lb))
        end
        puts '---' if args.count > 1
      end
    end

    private

    def colorize_yaml(yaml_string)
      yaml_string.split("\n").map do |line|
        if line =~ /:/
          key, val = line.split(':', 2)
          [Rainbow(key).bright, val].join(':')
        else
          line
        end
      end.join("\n")
    end

    def attributes(lb)
      Hash[connection.load_balancers.get(lb).attributes.map do |key, val|
        case key
        when Symbol
          [key.to_s.titlecase, val]
        when String
          [key.split(/(?=[A-Z])/).join(' '), val]
        end
      end]
    end

    def connection
      @connection ||= Fog::AWS::ELB.new
    end
  end
end
