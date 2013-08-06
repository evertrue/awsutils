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
      puts "New group ID: " + res.data[:body]["groupId"]
      @new_group_id = res.data[:body]["groupId"]
    end

    def generate_rule_opts( rule )

      if rule['source'] && rule['dest']
        raise "One of the predefined rules has both a source " +
          "and a destination already defined: " + rule.inspect
      end

      if ! rule['source']
        rule['source'] = @new_group_id
      elsif rule["source"] !~ /\./ && 
        ! current_groups.include?( rule['source'] )
        raise "Group #{rule['source']} specified as part of rule: #{rule.inspect} does not exist"
      end

      if ! rule['dest']
        rule['dest'] = @new_group_id
      elsif ! current_groups.include?( rule['dest'] )
        raise "Group #{rule['dest']} specified as part of rule: #{rule.inspect} does not exist"
      end

      ip_permissions = { "IpProtocol" => rule["proto"] }

      if rule["port"]

        ip_permissions["FromPort"] = rule["port"].first.to_s
        ip_permissions["ToPort"] = rule["port"].last.to_s

      end

      if rule["source"] =~ /\./

        ip_permissions["Groups"] = []
        ip_permissions["IpRanges"] = [ "CidrIp" => rule["source"] ]

      else

        ip_permissions["Groups"] = [
          {
            "GroupId" => rule["source"],
            "UserId" => @opts[:owner_group_id]
          }
        ]
        ip_permissions["IpRanges"] = []

      end

      options = { "IpPermissions" => [ ip_permissions ] }

      output = {
        "dest" => rule['dest'],
        "options" => options
      }

    end

    def save

      compiled_rules.each do |rule|

        begin

          puts "Rule inspect: #{rule.inspect}"

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

    def initialize
      @opts = Ec2SecurityGroup.parse_opts
    end

    def name
      @opts[:security_group]
    end

    def compiled_rules

      @compiled_rules ||= begin

        compiled_rules = []

        rules_data = YAML.load_file(@opts[:base_rules_file])

        if @opts[:environment]
          if ! rules_data["env"]
            raise "Environment #{@opts[:environment]} not present in rules file (#{@opts[:base_rules_file]})."
          else
            rules_env_data = rules_data["env"][@opts[:environment]]
          end
        elsif rules_data.class != Array
          raise "base_rules_file is an environment-keyed file but you did " +
            "not specify an environment."
        else
          rules_env_data = rules_data
        end

        rules_env_data.each do |rule|
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
        
      add_group

      begin

        compiled_rules

      rescue Exception => e

        puts "Error rescued.  Deleting newly created group."
        connection.delete_security_group( nil, @new_group_id )
        raise e

      end

      save

    end

  end

end
