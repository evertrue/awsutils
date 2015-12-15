#!/usr/bin/ruby

require 'rubygems'
require 'fog/aws'

module AwsUtils
  class Ec2SecurityGroup
    def connection
      @connection ||= Fog::Compute::AWS.new
    end

    def references(search)
      if search =~ /^sg-/
        search_id = search
      else
        search_id = groups.find { |g| g.name == search }.group_id
      end

      groups.each_with_object({}) do |grp, m|
        assoc_p = grp.ip_permissions.select do |ip_perm|
          !ip_perm['groups'].select { |src_grp|
            src_grp['groupName'] == search ||
              src_grp['groupId'] == search_id
          }.empty?
        end
        if assoc_p.empty?
          next
        else
          m[grp.name] = {
            'groupId' => grp.group_id,
            'ipPermissions' => assoc_p.map do |ap|
              ap.delete('ipRanges')
              ap
            end
          }
        end
      end
    end

    def groups
      @groups ||= connection.security_groups
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
