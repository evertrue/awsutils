require 'awsutils/ec2sg'
require 'trollop'

gem 'fog', '>= 1.6.0'

module AwsUtils
  class Ec2LsGrp < Ec2SecurityGroup
    attr_reader :search, :opts, :owner_id

    def msg_pair(key, value)
      puts("#{key} #{value}")
    end

    def perms_out(direction, perms)
      puts "#{direction.upcase} RULES"
      perms.to_enum.with_index(1) do |perm, index|
        print "  #{index} "
        print "groups: #{group_perm_string(perm['groups'])}; " if perm['groups'].count > 0
        print "ip_ranges: #{perm['ipRanges'].join(', ')}; " if perm['ipRanges'].count > 0
        print "ipProtocol: #{perm['ipProtocol']}; "
        print "fromPort: #{perm['fromPort']}; " if perm['fromPort']
        print "toPort: #{perm['toPort']}" if perm['toPort']
        print "\n"
      end
    end

    def group_details(g)
      @owner_id = g.owner_id

      msg_pair('ID', g.group_id)
      msg_pair('NAME', g.name)
      msg_pair('OWNER_ID', owner_id)
      msg_pair('DESCRIPTION', g.description)
      msg_pair('VPC_ID', g.vpc_id) if g.vpc_id

      perms_out('incoming', g.ip_permissions)
      perms_out('egress', g.ip_permissions_egress) if g.vpc_id
    end

    def run
      unless group_o = group(search) # rubocop:disable Lint/AssignmentInCondition
        puts 'No group found by that name/ID'
        exit 2
      end
      return group_details(group_o) unless opts[:list_refs]
      refs = references(group_o.group_id)
      if refs.empty?
        puts 'No references'
      else
        puts "References: #{refs.keys.join(', ')}"
        puts refs.to_yaml if opts[:verbose]
      end
    rescue Interrupt => e
      puts e.message
      exit 1
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

    def group_perm_string(group_perm)
      group_perm.map do |g|
        if g['userId'] == owner_id
          "#{g['groupId']} (#{group(g['groupId']).name})"
        else
          "#{g['groupId']} (#{g['groupName']}, owner: #{g['userId']})"
        end
      end.join(', ')
    end

    def parse_opts
      Trollop.options do
        opt :list_refs,
            'List groups referencing this group',
            short: 'r',
            default: false
        opt :verbose,
            'Verbose output (currently only used with -r output)',
            short: 'v',
            default: false
      end
    end

    def group(search)
      groups.find { |g| (search =~ /^sg-/ && g.group_id == search) || g.name == search }
    end
  end
end
