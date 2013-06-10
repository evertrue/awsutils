#!/usr/bin/ruby

require 'awsutils/ec2sg'

module AwsUtils

  class Ec2AddSecurityGroup < Ec2SecurityGroup

    def add_group
      res = connection.create_security_group( 
        @opts[:security_group], 
        "#{@opts[:security_group]} created by #{ENV['USER']}",
        @opts[:vpc_id]
      )
      @new_group_id = res.data[:body]["groupId"]
    end

    def generate_rule_opts( rule )

      if ! @opts[:security_group]
        raise "@opts[:security_group] not defined!"
      end

      if rule['source'] && rule['dest']
        raise "One of the predefined rules has both a source " +
          "and a destination already defined: " + rule.inspect
      end

      if ! rule['source']
        rule['source'] = @opts[:security_group]
      elsif rule["source"] !~ /\./ && 
        ! current_groups.include?( rule['source'] )
        raise "Group #{rule['source']} specified as part of rule: #{rule.inspect} does not exist"
      end

      if ! rule['dest']
        rule['dest'] = @opts[:security_group]
      elsif ! current_groups.include?( rule['dest'] )
        raise "Group #{rule['dest']} specified as part of rule: #{rule.inspect} does not exist"
      end

      if rule["source"] =~ /\./

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

        options = {
          "IpPermissions" => [
            {
              "FromPort" => rule["port"].first.to_s,
              "Groups" => [
                {
                  "GroupName" => rule["source"],
                  "UserId" => @opts[:owner_group_id]
                }
              ],
              "IpProtocol" => rule["proto"],
              "IpRanges" => [],
              "ToPort" => rule["port"].last.to_s
            }
          ]
        }

      end

      output = {
        "dest" => rule['dest'],
        "options" => options
      }

    end

    def save

      compiled_rules.each do |rule|

        begin

          # Amazon EC2 is neurotic about using group IDs with VPCs so
          # we'll use the group ID whenever possible. The reason we add
          # it here instead of when we compile the rule is so that we
          # can do rule compilation without first creating a new group.

          dest_group_id = connection.security_groups.get(rule["dest"]).group_id

          rule["options"]["GroupId"] = dest_group_id

          puts "Adding Rule: " + rule['options'].inspect
        
          connection.authorize_security_group_ingress( 
            dest_group_id, 
            rule["options"] 
          )

        rescue Excon::Errors::BadRequest => e

          puts "Request:"
          puts "dest_group_id: " + dest_group_id.inspect
          puts "rule[\"options\"]: " + rule['options'].inspect

          raise e

        end

      end
    end

    def initialize( args )
      @opts = Ec2SecurityGroup.parse_opts( args )
    end

    def name
      @opts[:security_group]
    end

    def compiled_rules

      @compiled_rules ||= begin

        compiled_rules = []

        YAML.load_file(@opts[:base_rules_file]).each do |rule|
          compiled_rules << generate_rule_opts( rule )
        end

        compiled_rules

      end

    end

    def run

      if ! File.exist?(@opts[:base_rules_file])
        puts "File #{@opts[:base_rules_file]} does not exist!"
        exit 1
      end

      if exist?
        puts "Group #{@opts[:security_group]} already exists!"
        exit 1
      end

      compiled_rules
        
      add_group

      save

    end

  end

end
