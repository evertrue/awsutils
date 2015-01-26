#!/usr/bin/ruby

require 'rubygems'
require 'fog/aws/compute'

module AwsUtils
  class Ec2SecurityGroup
    def connection
      @connection ||= Fog::Compute.new(provider: 'AWS')
    end

    def assigned?
      servers_using_group = connection.servers.map do |server|
        next unless server.state != 'terminated' &&
                    server.groups.include?(@opts[:security_group])
        server.tags['Name'] ? server.tags['Name'] : server.id
      end.compact

      return false unless servers_using_group.length > 0
      print 'The following servers are still using this group: '
      puts servers_using_group.join(',')

      true
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
