require 'awsutils/ec2sg'
require 'trollop'

gem 'fog', '>= 1.6.0'

module AwsUtils
  class Ec2LsGrp < Ec2SecurityGroup
    def lookup
      if @group =~ /^sg-/
        group_name = get_group_name(@group)
      else
        group_name = @group
      end

      connection.security_groups.get(group_name)
    end

    def msg_pair(key, value)
      puts("#{key} #{value}")
    end

    def perms_out(direction, perms)
      puts "#{direction.upcase} RULES"
      perms.to_enum.with_index(1) do |perm, index|
        print "  #{index} "
        if perm['groups'].count > 0
          groups_arr = perm['groups'].map do |g|
            "#{g['groupId']} (#{get_group_name(g['groupId'])})"
          end
          print "groups: #{groups_arr.join(', ')}; "
        end
        if perm['ipRanges'].count > 0
          print "ip_ranges: #{perm['ipRanges'].join(', ')}; "
        end
        print "ipProtocol: #{perm['ipProtocol']}; "
        print "fromPort: #{perm['fromPort']}; " if perm['fromPort']
        print "toPort: #{perm['toPort']}" if perm['toPort']
        print "\n"
      end
    end

    def run
      g = lookup

      if g.nil?
        puts 'No group found by that name.'
        exit 1
      end

      msg_pair('ID', g.group_id)
      msg_pair('NAME', g.name)
      msg_pair('OWNER_ID', g.owner_id)
      msg_pair('DESCRIPTION', g.description)
      msg_pair('VPC_ID', g.vpc_id) if g.vpc_id

      perms_out('incoming', g.ip_permissions)
      perms_out('egress', g.ip_permissions_egress) if g.vpc_id
    end

    def initialize
      unless args[0]
        puts 'Please specify a security group'
        exit 1
      end
      @opts = parse_opts
      @search = ARGV.last
    end

    private

    def allgroups
      unless @allgroups
        @allgroups = {}
        connection.describe_security_groups.data[:body]['securityGroupInfo']
          .select { |g| g['groupName'] }.each do |g|
          @allgroups[g['groupId']] = g['groupName']
        end
      end
      @allgroups
    end

    def parse_opts
      Trollop.options do
        opt :list_refs,
            'List groups referencing this group',
            short: 'r',
            default: false
      end
    end

    def get_group_name(id)
      allgroups[id]
    end
  end
end
