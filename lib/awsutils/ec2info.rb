require 'rubygems'
require 'fog/aws'
require 'awesome_print'

class String
  def underscore
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end

  def title_case
    underscore.split('_').map do |word|
      # Recognize certain special cases (e.g. acronyms)
      if %w(iam ebs id dns vpc).include? word.downcase
        word.upcase
      elsif word.casecmp('ids').zero?
        'IDs'
      else
        word.capitalize
      end
    end.join(' ')
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

    def instances
      @instance_ids ||= begin
        if $DEBUG
          puts 'Entering instance_ids'
          puts "Search Term: #{search_terms.inspect}"
        end

        instance_ids = search_terms.each_with_object([]) do |search_term, m|
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

        if instance_ids.empty?
          puts 'No instances by that Name/ID in this account'
          exit 1
        end

        puts "Found instances: #{results.inspect}" if $DEBUG

        ec2.servers.all 'instance-id' => instance_ids
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

    def printkv(key, value)
      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      print "#{key_color}#{key.to_s.title_case}:#{reset_color} "
      case
      when value.respond_to?(:to_sym)
        puts value
      when value.respond_to?(:key?)
        puts
        value.each { |k, v| printkv "  #{k}", v }
      when (
        value.respond_to?(:join) &&
        value.reject { |item| item.respond_to?(:to_sym) }.empty? # If value only contains strings, do this
      )
        value.join(', ')
      else
        puts value.inspect
      end
    end

    def describe_instance
      col_green = "\033[32;1m" # Style: Bold; Color: Green
      col_red = "\033[31;1m" # Style: Bold; Color: Red
      # col_blinking_red = "\033[31;5m"

      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      instances.each do |instance|
        puts "#{key_color}NAME:#{reset_color} #{instance.tags['Name']}"
        puts

        instance.attributes.each do |instance_attribute, _value|
          puts "Instance attribute: #{instance_attribute}" if $DEBUG

          case instance_attribute
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
          when :product_codes
            if instance.product_codes.any?
              puts "#{key_color}Product Codes:#{reset_color} #{instance.product_codes.join(',')}"
            elsif $DEBUG
              puts "#{key_color}Product Codes:#{reset_color} N/A"
            end
          when :public_ip_address
            if ec2.addresses.get(instance.public_ip_address)
              puts "#{key_color}Public IP Address:#{reset_color} " \
                   "#{instance.public_ip_address} (#{col_green}STATIC#{reset_color})"
            else
              puts "#{key_color}Public IP Address:#{reset_color} " \
                   "#{instance.public_ip_address} (#{col_red}DYNAMIC#{reset_color})"
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
          when :tags
            if instance.tags.any?
              puts "#{key_color}Tags:#{reset_color} "

              instance.tags.each do |tag, value|
                puts "\t#{key_color}#{tag}:#{reset_color} #{value}"
              end
            else
              puts "#{key_color}Tags:#{reset_color} None"
            end
          else
            if instance.respond_to?(instance_attribute) && !instance.send(instance_attribute).nil?
              printkv instance_attribute, instance.send(instance_attribute)
            else
              printkv instance_attribute, '<NULL>'
            end
          end
        end

        if instance.instance_initiated_shutdown_behavior
          puts "#{key_color}Shutdown Behavior:#{reset_color} " \
               "#{instance.instance_initiated_shutdown_behavior}"
        else
          puts "#{key_color}Shutdown Behavior:#{reset_color} Do nothing"
        end

        if instance.id != instances.last.id
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
