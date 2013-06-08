#!/usr/bin/ruby

require 'awsutils/ec2sg'

module AwsUtils

  class Ec2AddSecurityGroup < Ec2SecurityGroup

    def add_group

      connection.create_security_group( 
        @target_group, 
        "#{@target_group} created by #{ENV['USER']}" 
      )

    end

    def create_rule( rule )

      if ! rule['source']
        rule['source'] = @target_group
      end

      if ! rule['dest']
        rule['dest'] = @target_group
      end

      if rule["source"] =~ /\./

        puts "Adding CIDR Rule: { Target: #{rule["dest"]}, Source: #{rule["source"]}, " +
          "Ports: #{rule["proto"]}/#{rule["port"].to_s} }"

        options = {
          "IpPermissions" => [
            {
              "FromPort" => rule["port"].first.to_s,
              "Groups" => [],
              "IpProtocol" => rule["proto"],
              "IpRanges" => [
                "CidrIp" => rule["source"]
              ],
              "ToPort" => rule["port"].last.to_s
            }
          ]
        }

      else

        puts "Adding Group Rule: { Target: #{rule["dest"]}, Source: #{rule["source"]}, " +
          "Ports: #{rule["proto"]}/#{rule["port"].to_s} }"

        options = {
          "IpPermissions" => [
            {
              "FromPort" => rule["port"].first.to_s,
              "Groups" => [
                {
                  "GroupName" => rule["source"],
                  "UserId" => GROUP_OWNER_ID
                }
              ],
              "IpProtocol" => rule["proto"],
              "IpRanges" => [],
              "ToPort" => rule["port"].last.to_s
            }
          ]
        }

      end
      
      connection.authorize_security_group_ingress( 
        rule["dest"], 
        options 
      )

    end

    def initialize

      parse_opts

      base_rules = ARGV[1] || 
        ENV['EC2_BASE_RULES'] ||
        ENV['HOME'] + "/.ec2baserules.yml"

      if ! File.exist?(base_rules)
        puts "File #{base_rules} does not exist!"
        exit 1
      end
      
      add_group

      YAML.load_file(base_rules).each do |new_rule|

        create_rule( new_rule )

      end

    end

  end

end
