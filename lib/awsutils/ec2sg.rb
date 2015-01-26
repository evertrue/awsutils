#!/usr/bin/ruby

require 'rubygems'
require 'fog/aws/compute'

module AwsUtils
  class Ec2SecurityGroup
    def connection
      @connection ||= Fog::Compute.new(provider: 'AWS')
    end

    def assigned?

      servers_using_group = Array.new

      connection.servers.each do |server|
        if (server.state != "terminated") &&
          server.groups.include?( @opts[:security_group] )
          if defined?server.tags.has_key?("Name")
            servers_using_group << server.tags["Name"]
          else
            servers_using_group << server.id
          end
        end
      end

      if servers_using_group.length > 0

        print "The following servers are still using this group: "
        puts servers_using_group.join(",")

        return true

      else

        return false

      end

    end

    def exist?
      current_groups.include?(@opts[:security_group])
    end

    def current_groups
      @current_groups ||= begin
        connection.security_groups.map { |g| [g.name, g.group_id] }.flatten.uniq
      end
    end
  end
end
