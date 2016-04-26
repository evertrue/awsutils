require 'rubygems'
require 'fog/aws'

class String
  def title_case
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map { |e| e.capitalize }.join(' ')
  end
end

class Array
  def longest
    length = 0
    val = ''
    each do |a|
      len_new = a.length
      if len_new > length
        length = len_new
        val = a
      end
    end
    val
  end
end

module AwsUtils
  class Ec2Info
    attr_reader :search_terms

    def ec2
      @ec2 ||= Fog::Compute.new(provider: 'AWS')
    end

    def instance_ids
      @instance_ids ||= begin
        if $DEBUG
          puts 'Entering instance_ids'
          puts "Search Term: #{search_terms.inspect}"
        end

        results = search_terms.each_with_object([]) do |search_term, m|
          if (/^i-/ =~ search_term) && !(/\./ =~ search_term)
            m << search_term
          else
            ec2.servers.each do |server|
              next unless server.tags.key?('Name') \
                && (server.tags['Name'] != '') \
                && (/#{search_term}/i =~ server.tags['Name'])
              m << server.id
            end
          end
        end

        if results.empty?
          puts 'No instances by that Name/ID in this account'
          exit 1
        end

        puts "Found instances: #{results.inspect}" if $DEBUG

        results
      end
    end

    def get_flavor_color(flavor)
      fcolor =
        case flavor
        when 't1.micro'
          '1;33'
        when 'm1.large'
          '0;33'
        when 'm1.xlarge'
          '0;34'
        when 'm2.2xlarge'
          '0;35'
        when 'm2.4xlarge'
          '0;31'
        when 'm2.xlarge'
          '0;36'
        else
          '0'
        end

      "\033[#{fcolor}m"
    end

    def get_state_color(state)
      scolor =
        case state
        when 'running'
          '1;32'
        when 'stopped'
          '1;31'
        when 'starting'
          '5;32'
        when 'stopping'
          '5;31'
        else
          '0'
        end

      "\033[#{scolor}m"
    end

    def describe_instance_short
      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      printf("#{key_color}%-50s %-11s %-12s %-13s %-10s %s#{reset_color}\n",
             'Name',
             'Zone',
             'ID',
             'Group',
             'Flavor',
             'State'
            )

      instance_ids.each do |instance_id|
        inst = ec2.servers.get(instance_id)

        s_color = get_state_color(inst.state)
        f_color = get_flavor_color(inst.flavor_id)

        printf(
          "%-50s %-11s %-12s %-13s #{f_color}%-10s#{reset_color} #{s_color}%s#{reset_color}",
          inst.tags['Name'],
          inst.availability_zone,
          inst.id,
          inst.groups.first,
          inst.flavor_id,
          inst.state
        )
      end
    end

    def describe_instance
      instance_attribute_index = ec2.servers.first.class.attributes
        # ec2.servers.first.class.attributes.reject { |attr| attr == :vpc_id }

      puts "Built attribute index: #{instance_attribute_index.inspect}" if $DEBUG

      col_green = "\033[32;1m" # Style: Bold; Color: Green
      col_red = "\033[31;1m" # Style: Bold; Color: Red
      # col_blinking_red = "\033[31;5m"

      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      instance_ids.each do |instance_id|
        instance = ec2.servers.get instance_id

        puts "#{key_color}NAME:#{reset_color} #{instance.tags['Name']}"
        puts

        instance_attribute_index.each do |instance_attribute|
          puts "Instance attribute: #{instance_attribute}" if $DEBUG

          case instance_attribute
          when :id
            puts "#{key_color}ID:#{reset_color} #{instance.id}"
          when :ami_launch_index
            puts "#{key_color}AMI Launch Index:#{reset_color} #{instance.ami_launch_index}"
          when :availability_zone
            puts "#{key_color}Availability Zone:#{reset_color} #{instance.availability_zone}"
          when :block_device_mapping
            puts "#{key_color}Block Devices:#{reset_color} "

            instance.block_device_mapping.each do |vol|
              vol_obj = ec2.volumes.get(vol['volumeId'])

              puts "\t#{key_color}Size:#{reset_color} #{vol_obj.size} GB"
              puts "\t#{key_color}Volume ID:#{reset_color} #{vol_obj.id}"
              puts "\t#{key_color}Device Name:#{reset_color} #{vol_obj.device}"

              if vol_obj.delete_on_termination
                puts "\t#{key_color}Delete on Termination:#{reset_color} " \
                  "#{col_red}YES#{reset_color}"
              else
                puts "\t#{key_color}Delete on Termination:#{reset_color} " \
                  "#{col_green}NO#{reset_color}"
              end

              puts "\t#{key_color}Attach Time:#{reset_color} #{vol_obj.attached_at}"
              puts "\t#{key_color}Creation Time:#{reset_color} #{vol_obj.created_at}"

              if vol_obj.snapshot_id
                snap_obj = ec2.snapshots.get(vol_obj.snapshot_id)

                print "\t#{key_color}Snapshot ID:#{reset_color} #{vol_obj.snapshot_id}"

                puts " (Created: #{snap_obj.created_at})" if defined?(snap_obj.created_at)

                if defined?(snap_obj.tags) && snap_obj.tags != {}
                  puts "\t\t#{key_color}Tags:#{reset_color}"

                  snap_obj.tags.each do |snap_tag, snap_tag_value|
                    puts "\t\t\t#{key_color}#{snap_tag}:#{reset_color} #{snap_tag_value}"
                  end
                end
              end

              puts "\t#{key_color}State:#{reset_color} #{vol_obj.state}" if vol_obj.state != 'in-use'

              status_color =
                if vol['status'] == 'attached'
                  col_green
                else
                  col_red
                end

              puts "\t#{key_color}Status:#{reset_color} #{status_color}#{vol['status']}#{reset_color}"

              if vol_obj.tags != {}
                puts "\t#{key_color}Tags:#{reset_color}"

                vol_obj.tags.each do |vol_tag, vol_tag_value|
                  puts "\t\t#{key_color}#{vol_tag}:#{reset_color} #{vol_tag_value}"
                end

              end

              if vol != instance.block_device_mapping.last
                puts "\t---------------------------------------"
              end
            end

          when :client_token
            if instance.client_token
              puts "#{key_color}Client Token:#{reset_color} #{instance.client_token}"
            elsif $DEBUG
              puts "#{key_color}Client Token:#{reset_color} N/A"
            end
          when :dns_name
            puts "#{key_color}DNS Name:#{reset_color} #{instance.dns_name}"
          when :groups
            instance.groups.each do |group_id|
              group = ec2.security_groups.get(group_id)

              next unless group
              puts "#{key_color}Security Group:#{reset_color} #{group.name}"
              puts "\t#{key_color}Description:#{reset_color} #{group.description}"
              puts "\t#{key_color}ID:#{reset_color} #{group.group_id}"
              break
            end

          when :flavor_id
            instance_flavor = ec2.flavors.get(instance.flavor_id)

            puts "#{key_color}Flavor:#{reset_color} #{instance_flavor.id}"

            puts "\t#{key_color}Name:#{reset_color} #{instance_flavor.name}"
            puts "\t#{key_color}Architecture:#{reset_color} #{instance_flavor.bits} bit"
            puts "\t#{key_color}Cores:#{reset_color} #{instance_flavor.cores}"
            puts "\t#{key_color}Instance Storage (in /mnt):#{reset_color} #{instance_flavor.disk} GB"
            puts "\t#{key_color}RAM:#{reset_color} #{instance_flavor.ram} MB"
          when :image_id
            puts "#{key_color}Image ID:#{reset_color} #{instance.image_id}"

            image_obj = ec2.images.get(instance.image_id)

            puts "\t#{key_color}Name:#{reset_color} #{image_obj.name}" if defined?(image_obj.name)

            if defined?(image_obj.description)
              puts "\t#{key_color}Description:#{reset_color} #{image_obj.description}"
            end

            if defined?(image_obj.location)
              puts "\t#{key_color}Location:#{reset_color} #{image_obj.location}"
            end

            if defined?(image_obj.architecture)
              puts "\t#{key_color}Arch:#{reset_color} #{image_obj.architecture}"
            end

            if defined?(image_obj.tags) && (image_obj.tags != {})
              puts "\t#{key_color}Tags:#{reset_color}"

              image_obj.tags.each do |image_tag, image_tag_value|
                puts "\t\t#{key_color}#{image_tag}: #{image_tag_value}"
              end
            end
          when :kernel_id
            puts "#{key_color}Kernel ID:#{reset_color} #{instance.kernel_id}"
          when :key_name
            puts "#{key_color}SSH Key:#{reset_color} #{instance.key_name}"
          when :created_at
            puts "#{key_color}Created Date:#{reset_color} #{instance.created_at}"
          when :monitoring
            puts "#{key_color}Monitoring:#{reset_color} #{instance.monitoring}"
          when :placement_group
            if instance.placement_group
              puts "#{key_color}Placement Group:#{reset_color} #{instance.placement_group}"
            elsif $DEBUG
              puts "#{key_color}Placement Group:#{reset_color} N/A"
            end
          when :platform
            if instance.platform
              puts "#{key_color}Platform:#{reset_color} #{instance.platform}"
            elsif $DEBUG
              puts "#{key_color}Platform:#{reset_color} N/A"
            end
          when :product_codes
            if instance.product_codes.any?
              puts "#{key_color}Product Codes:#{reset_color} #{instance.product_codes.join(',')}"
            elsif $DEBUG
              puts "#{key_color}Product Codes:#{reset_color} N/A"
            end
          when :private_dns_name
            puts "#{key_color}Private DNS Name:#{reset_color} #{instance.private_dns_name}"
          when :private_ip_address
            puts "#{key_color}Private IP Address:#{reset_color} #{instance.private_ip_address}"
          when :public_ip_address
            if ec2.addresses.get(instance.public_ip_address)
              puts "#{key_color}Public IP Address:#{reset_color} " \
                   "#{instance.public_ip_address} (#{col_green}STATIC#{reset_color})"
            else
              puts "#{key_color}Public IP Address:#{reset_color} " \
                   "#{instance.public_ip_address} (#{col_red}DYNAMIC#{reset_color})"
            end
          when :ramdisk_id
            if instance.ramdisk_id
              puts "#{key_color}Ramdisk ID:#{reset_color} #{instance.ramdisk_id}"
            elsif $DEBUG
              puts "#{key_color}Ramdisk ID:#{reset_color} N/A"
            end
          when :reason
            if instance.reason
              puts "#{key_color}State Reason:#{reset_color} #{instance.reason}"
            elsif $DEBUG
              puts "#{key_color}State Reason:#{reset_color} N/A"
            end
          when :root_device_name
            if instance.root_device_name
              puts "#{key_color}Root Device Name:#{reset_color} #{instance.root_device_name}"
            elsif $DEBUG
              puts "#{key_color}Root Device Name:#{reset_color} N/A"
            end
          when :root_device_type
            if instance.root_device_type
              puts "#{key_color}Root Device Type:#{reset_color} #{instance.root_device_type}"
            elsif $DEBUG
              puts "#{key_color}Root Device Name:#{reset_color} N/A"
            end
          when :security_group_ids
            if instance.security_group_ids
              puts "#{key_color}Security Group IDs:#{reset_color} #{instance.security_group_ids}"
            elsif $DEBUG
              puts "#{key_color}Security Group IDs:#{reset_color} N/A"
            end
          when :state
            state_color = get_state_color(instance.state)
            puts "#{key_color}State:#{reset_color} #{state_color}#{instance.state}#{reset_color}"
          when :state_reason
            if instance.state_reason.any?
              puts "#{key_color}State Reason Code:#{reset_color} #{instance.state_reason["Code"]}"
            elsif $DEBUG
              puts "#{key_color}State Reason Code:#{reset_color} N/A"
            end
          when :subnet_id
            if instance.subnet_id
              puts "#{key_color}Subnet ID:#{reset_color} #{instance.subnet_id}"
            elsif $DEBUG
              puts "#{key_color}Subnet ID:#{reset_color} N/A"
            end
          when :tenancy
            puts "#{key_color}Tenancy:#{reset_color} #{instance.tenancy}"
          when :tags
            if instance.tags.any?
              puts "#{key_color}Tags:#{reset_color} "

              instance.tags.each do |tag, value|
                puts "\t#{key_color}#{tag}:#{reset_color} #{value}"
              end
            else
              puts "#{key_color}Tags:#{reset_color} None"
            end
          when :user_data
            if instance.user_data
              puts "#{key_color}User Data:#{reset_color} #{instance.user_data}"
            elsif $DEBUG
              puts "#{key_color}User Data:#{reset_color} N/A"
            end
          when :vpc_id
            if instance.vpc_id
              puts "#{key_color}VPC ID:#{reset_color} #{instance.vpc_id}"
            elsif $DEBUG
              puts "#{key_color}VPC ID: #{reset_color} N/A"
            end
          else
            print "#{key_color}#{instance_attribute.to_s.title_case}:#{reset_color} "
            puts instance.respond_to?(:instance_attribute) ? '' : '<NULL>'
          end
        end

        if instance.instance_initiated_shutdown_behavior
          puts "#{key_color}Shutdown Behavior:#{reset_color} " \
               "#{instance.instance_initiated_shutdown_behavior}"
        else
          puts "#{key_color}Shutdown Behavior:#{reset_color} Do nothing"
        end

        if instance_id != instance_ids.last
          puts '------------------------------------------------------------------------------------'
        end
      end
    end

    def initialize
      if (ARGV[0] == '') || !ARGV[0]
        puts 'Please specify a search term (Host Name or Instance ID)'
        exit 1
      end

      args = ARGV

      if args.include?('-s') || args.include?('--short')
        args.delete '-s'
        args.delete '--short'

        @search_terms = args

        describe_instance_short
      else
        @search_terms = args
        describe_instance
      end
    end
  end
end
