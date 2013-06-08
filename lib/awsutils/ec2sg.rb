#!/usr/bin/ruby

require 'rubygems'
require 'fog'

module AwsUtils

  class Ec2SecurityGroup

    def connection
      @connection ||= begin
        connection = Fog::Compute.new(:provider => 'AWS')
      end
    end

    def is_group_in_use

      servers_using_group = Array.new

      connection.servers.each do |server|
        if (server.state != "terminated") && 
          server.groups.include?( @target_group )
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
        
        exit 1

      end

    end

    def does_group_exist

      if ! connection.security_groups.get( @target_group )

        puts "Group does not exist"

        exit 1

      end

    end

    def parse_opts

      if (ARGV[0] == nil) or (ARGV[0] == "")

        puts "Please specify a security group"
        exit 1

      elsif ! ENV['AWS_OWNER_ID']

        puts "Please set the AWS_OWNER_ID environment variable."
        exit 1

      else

        @target_group = ARGV[0]
        OWNER_GROUP_ID = ENV['AWS_OWNER_ID']

      end

    end

  end

end
