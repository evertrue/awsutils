#!/usr/bin/ruby

require 'rubygems'
require 'trollop'
require 'fog'

module AwsUtils

  class Ec2SecurityGroup

    def connection
      @connection ||= Fog::Compute.new(:provider => 'AWS')
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
      if ! current_groups.include?( @opts[:security_group] )
        return false
      else
        return true
      end
    end

    def current_groups
      @current_groups ||= begin

        current_groups = connection.security_groups.map{|g|
          [g.name,g.group_id]
        }.flatten.reject{|g| g == nil }.uniq
        
      end
    end

    def self.parse_opts

      if ! ENV['AWS_OWNER_ID']
        raise "Environment variable AWS_OWNER_ID is not set!"
      end

      @opts = Trollop::options do
        opt :security_group, "New Security Group Name", :short => 'N', :type => String, :required => true
        opt :vpc_id, "New Group VPC ID", :short => 'v', :type => String
        opt :base_rules_file, "Base rules YAML file", :short => 'r', :default => ENV['EC2_BASE_RULES'] || ENV['HOME'] + "/.ec2baserules.yml"
        opt :description, "New Group Description", :short => 'd', :type => String
        opt :owner_group_id, "Owner Group ID", :short => 'o', :default => ENV['AWS_OWNER_ID']
      end

    end

  end

end
