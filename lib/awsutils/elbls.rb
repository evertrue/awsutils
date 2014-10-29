require 'fog'
require 'facets/string/titlecase'
require 'rainbow'

module AwsUtils
  class ElbLs
    attr_reader :args

    def run(args)
      @args = args

      puts colorize_yaml(attributes)
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

    def attributes
      Hash[lb.attributes.map do |key, val|
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
