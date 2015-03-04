require 'awsutils/ec2sg'
require 'trollop'

gem 'fog', '>= 1.6.0'

module AwsUtils
  class Ec2LsGrp < Ec2SecurityGroup
    def msg_pair(key, value)
      puts("#{key} #{value}")
    end

    def perms_out(direction, perms)
      puts "#{direction.upcase} RULES"
      perms.to_enum.with_index(1) do |perm, index|
        print "  #{index} "
        if perm['groups'].count > 0
          groups_arr = perm['groups'].map do |g|
            "#{g['groupId']} (#{group(g['groupId']).name})"
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

    def group_details(g)
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

    def run
      group_o = group(@search)
      return group_details(group_o) unless @opts[:list_refs]
      refs = references(group_o.group_id)
      if refs.empty?
        puts 'No references'
      else
        puts "References: #{refs.keys.join(', ')}"
      end
    end

    def initialize
      unless ARGV[0]
        puts 'Please specify a security group'
        exit 1
      end
      @opts = parse_opts
      @search = ARGV.last
    end

    private

    def parse_opts
      Trollop.options do
        opt :list_refs,
            'List groups referencing this group',
            short: 'r',
            default: false
      end
    end

    def group(search)
      groups.find do |g|
        (search =~ /^sg-/ &&
          g.group_id == search) ||
          g.name == search
      end
    end
  end
end
