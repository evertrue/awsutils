require 'rubygems'
require 'fog'

gem 'fog', '>= 1.6.0'

module AwsUtils

	class Ec2LsGrp

		def connection
			@connection ||= Fog::Compute.new(:provider => "AWS")
		end

		def lookup
			connection.security_groups.get(@group)
		end

		def msg_pair( key, value )
			puts("#{key} #{value}")
		end

		def perms_out( direction, perms )
			puts "#{direction.upcase} RULES"
			perms.to_enum.with_index(1) do |perm,index|
				
				print "  #{index} "
				if perm['groups'].count > 0
					groups_arr = perm['groups'].map{|g| g['groupId']}
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

			msg_pair('ID', g.group_id)
			msg_pair('NAME', g.name)
			msg_pair('OWNER_ID', g.owner_id)
			msg_pair('DESCRIPTION', g.description)
			msg_pair('VPC_ID', g.vpc_id) if g.vpc_id

			perms_out('incoming', g.ip_permissions)
			perms_out('egress', g.ip_permissions_egress) if g.vpc_id
		end

		def initialize( args )
			if ! args[0]
				puts "Please specify a security group"
				exit 1
			end
			@group = args[0]
		end

	end

end
