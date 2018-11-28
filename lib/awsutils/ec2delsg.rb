#!/usr/bin/ruby

require 'awsutils/ec2sg'

module AwsUtils
  class Ec2DeleteSecurityGroup < Ec2SecurityGroup
    def references
      @references ||= begin
        references = []

        connection.security_groups.each do |group|
          group.ip_permissions.each do |ip_perm|
            ip_perm['groups'].each do |src_grp|
              next unless src_grp['groupName'] == @opts[:security_group]

              options = {
                'IpPermissions' => [
                  {
                    'FromPort' => ip_perm['fromPort'],
                    'Groups' => [
                      {
                        'GroupName' => @opts[:security_group],
                        'UserId' => @opts[:owner_group_id]
                      }
                    ],
                    'IpProtocol' => ip_perm['ipProtocol'],
                    'IpRanges' => [],
                    'ToPort' => ip_perm['toPort']
                  }
                ]
              }

              references << {
                'group_name' => group.name,
                'options' => options
              }
            end
          end
        end

        references
      end
    end

    def delete_group_refs
      references.each do |ref|
        puts 'Removing rule: ' + ref.inspect

        connection.revoke_security_group_ingress(
          ref['group_name'],
          ref['options']
        )
      end
    end

    def initialize(args)
      @opts = Ec2SecurityGroup.parse_opts(args)
    end

    def name
      @opts[:security_group]
    end

    def run
      unless exist?
        puts 'Specified group does not exist.'
        exit 1
      end

      if assigned?
        puts 'Group is still assigned to one or more instances.'
        exit 1
      end

      delete_group_refs

      puts "Deleting group #{@opts[:security_group]}."
      connection.delete_security_group(nil,
                                       connection.security_groups.get(@opts[:security_group]).group_id)
    end
  end
end
