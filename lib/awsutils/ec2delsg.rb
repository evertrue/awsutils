#!/usr/bin/ruby

require 'awsutils/ec2sg'

module AwsUtils

  class Ec2DeleteSecurityGroup < Ec2SecurityGroup

    def delete_group_refs

      connection.security_groups.each do |group|
        group.ip_permissions.each do |ip_perm|
          ip_perm["groups"].each do |src_grp|
            if src_grp["groupName"] == @target_group

              puts "Removing rule: { Group: #{group.name}, " +
                "Rule: #{ip_perm["ipProtocol"]}" +
                "/#{ip_perm["fromPort"]}..#{ip_perm["toPort"]} }"

              options = {
                "IpPermissions" => [
                  {
                    "FromPort" => ip_perm["fromPort"],
                    "Groups" => [
                      {
                        "GroupName" => @target_group,
                        "UserId" => OWNER_GROUP_ID
                      }
                    ],
                    "IpProtocol" => ip_perm["ipProtocol"],
                    "IpRanges" => [],
                    "ToPort" => ip_perm["toPort"]
                  }
                ]
              }

              connection.revoke_security_group_ingress( group.name, options )

            end
          end
        end
      end

    end

    def initialize

      parse_opts

      is_group_in_use
      does_group_exist
      delete_group_refs

      puts "Deleting group #{target_group}."
      
      connection.delete_security_group( @target_group )

    end

  end

end
