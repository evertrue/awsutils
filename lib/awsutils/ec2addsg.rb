#!/usr/bin/ruby

require 'awsutils/ec2sg'

module AwsUtils

  class Ec2AddSecurityGroup < Ec2SecurityGroup

    def g_obj

      @g_obj ||= begin
          connection.security_groups.new(
            :name => @opts[:security_group],
            :description => "#{@opts[:description]}",
            :vpc_id => @opts[:vpc_id]
          )
      end

    end

    def generate_rule_hash( rule )

      if rule['source']
        if rule['dest']
          raise "One of the predefined rules has both a source " +
            "and a destination already defined: " + rule.inspect
        end
        if rule["source"] !~ /\./ &&
          ! current_groups.include?( rule['source'] )
          raise "Group #{rule['source']} specified as part of rule: #{rule.inspect} does not exist"
        end
      end

      if ! rule['dest']
        rule['dest'] = @new_group_id
      elsif ! current_groups.include?( rule['dest'] )
        raise "Group #{rule['dest']} specified as part of rule: #{rule.inspect} does not exist"
      end

      ip_permissions = {}

      if rule["proto"]
        ip_permissions["IpProtocol"] = rule["proto"]
      end

      if rule["port"]

        ip_permissions["FromPort"] = rule["port"].first.to_s
        ip_permissions["ToPort"] = rule["port"].last.to_s

      end

      if rule["source"] =~ /\./

        ip_permissions["Groups"] = []
        ip_permissions["IpRanges"] = [ "CidrIp" => rule["source"] ]

      elsif rule["source"]

        ip_permissions["Groups"] = [
          {
            "GroupId" => rule["source"],
            "UserId" => @opts[:owner_group_id]
          }
        ]
        ip_permissions["IpRanges"] = []

      end

      rule["IpPermissions"] = [ ip_permissions ]

      return rule

    end

    def add_rule_to_other_group( rule )

      rule["IpPermissions"].each do |r|
        r["Groups"] = [
          {
            "GroupId" => g_obj.group_id,
            "UserId" => @opts[:owner_group_id]
          }
        ]
      end

      puts "Adding Outbound Rule: " + rule.inspect

      connection.authorize_security_group_ingress(nil,
          {
            "GroupId" => rule["dest"],
            "IpPermissions" => rule["IpPermissions"]
          }
        )

    end

    def add_rule_to_this_group( rule )

      rule["IpPermissions"].each do |r|
        r["Groups"] = [
          {
            "GroupId" => rule["source"],
            "UserId" => @opts[:owner_group_id]
          }
        ]
        r["dest"] = g_obj.group_id
      end

      puts "Adding Inbound Rule: " + rule.inspect

      connection.authorize_security_group_ingress(nil,
          {
            "GroupId" => g_obj.group_id,
            "IpPermissions" => rule["IpPermissions"]
          }
        )

    end

    def save( rules )

      #g_obj.ip_permissions = []

      # Then create the group
      g_obj.save
      puts "New group ID: #{g_obj.group_id}"

      begin

        rules.reject {|rule| rule["dest"] }.each do |rule|
          add_rule_to_this_group( rule )
        end

        # Then process the outbound rules now that we have a group_id
        rules.select {|rule| rule["dest"] }.each do |rule|
          add_rule_to_other_group( rule )
        end

      rescue Exception => e

        connection.delete_security_group(nil,g_obj.group_id)
        raise e

      end


    end

    def initialize
      @opts = Ec2SecurityGroup.parse_opts
    end

    def name
      @opts[:security_group]
    end

    def compile_rules

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
        compiled_rules << generate_rule_hash( rule )
      end

      compiled_rules

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

      compiled_rules = compile_rules

      save( compiled_rules )

    end

  end

end
