require 'rubygems'
require 'fog/aws'

class Array

	def longest
		length = 0
		val = String.new
		self.each do |a|
			len_new = a.length
			if len_new > length
				length = len_new
				val = a
			end
		end
		return val
	end
end

module AwsUtils

  class Ec2Info

  	def connect()
  	
  		conn = Fog::Compute.new(:provider => 'AWS')
  		
  		if $DEBUG
  		
  			puts "Inspect connection result:"
  			puts conn.inspect
  			
  		end
  		
  		#puts conn.inspect
  		
  		return conn
  		
  	end

    def get_instance_id(conn,search_terms)

      if $DEBUG

        puts "Entering get_instance_id"
        puts "Search Term: #{search_terms.inspect}"

      end

      instance_ids = Array.new

      search_terms.each do |search_term|

        if (/^i-/ =~ search_term) && (!(/\./ =~ search_term))

          instance_ids[0] = search_term

        else

          conn.servers.each do |server|

            if (server.tags.has_key?("Name")) \
              && (server.tags["Name"] != "") \
              && (/#{search_term}/i =~ server.tags["Name"])

                instance_ids << server.id

            end

          end

        end

      end

      if (instance_ids.count < 1)

        puts "No instances by that Name/ID in this account"

        exit 1

      end

      if $DEBUG

        puts "Found instances: #{instance_ids.inspect}"

      end

      return instance_ids

    end

    def get_flavor_color(flavor)

  			case flavor
          when "t1.micro"
            fcolor = "1;33"
          when "m1.large"
            fcolor = "0;33"
          when "m1.xlarge"
            fcolor = "0;34"
          when "m2.2xlarge"
            fcolor = "0;35"
          when "m2.4xlarge"
            fcolor = "0;31"
          when "m2.xlarge"
            fcolor = "0;36"
          else
            fcolor = "0"
  			end

        return "\033[#{fcolor}m"

    end

    def get_state_color(state)

  			case state
          when "running"
            scolor="1;32"
          when "stopped"
            scolor="1;31"
          when "starting"
            scolor="5;32"
          when "stopping"
            scolor="5;31"
          else
            scolor="0"
  			end

        return "\033[#{scolor}m"

    end

    def describe_instance_short(search_term)

      conn = connect()

      instance_ids = Array.new

      instance_ids = get_instance_id(conn,search_term)

      instance_attribute_index = Array.new

      conn.servers.first.class.attributes.each do |cur_attr|

        instance_attribute_index << cur_attr

      end

      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      printf("#{key_color}%-50s %-11s %-12s %-13s %-10s %s#{reset_color}\n",
             "Name",
             "Zone",
             "ID",
             "Group",
             "Flavor",
             "State"
            )

      instance_ids.each do |instance_id|

        inst = conn.servers.get(instance_id)
        
        s_color = get_state_color(inst.state)
        f_color = get_flavor_color(inst.flavor_id)

        printf("%-50s %-11s %-12s %-13s #{f_color}%-10s#{reset_color} #{s_color}%s#{reset_color}",
               inst.tags['Name'],
               inst.availability_zone,
               inst.id,
               inst.groups.first,
               inst.flavor_id,
               inst.state
              )

      end


    end
  	
  	def describe_instance(search_term)
  	
  		conn = connect()

      instance_ids = Array.new

      instance_ids = get_instance_id(conn,search_term)

      instance_attribute_index = Array.new

      conn.servers.first.class.attributes.each do |cur_attr|

        instance_attribute_index << cur_attr

      end

      if $DEBUG

        puts "Built attribute index: #{instance_attribute_index.inspect}"

      end

      col_green = "\033[32;1m" # Style: Bold; Color: Green
      col_red = "\033[31;1m" # Style: Bold; Color: Red
      col_blinking_red = "\033[31;5m"

      key_color = "\033[30;1m" # Style: Bold; Color: Default
      reset_color = "\033[0m"

      instance_ids.each do |instance_id|
  		
  		  instance = conn.servers.get(instance_id)

        puts "#{key_color}NAME:#{reset_color} #{instance.tags['Name']}"
        puts ""

        instance_attribute_index.delete("vpc_id")

        instance_attribute_index.each do |instance_attribute|

          if $DEBUG

            puts "Instance attribute: #{instance_attribute}"

          end

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

              vol_obj = conn.volumes.get(vol['volumeId'])

              puts "\t#{key_color}Size:#{reset_color} #{vol_obj.size} GB"
              puts "\t#{key_color}Volume ID:#{reset_color} #{vol_obj.id}"
              puts "\t#{key_color}Device Name:#{reset_color} #{vol_obj.device}"

              if (vol_obj.delete_on_termination == true)

                puts "\t#{key_color}Delete on Termination:#{reset_color} " +
                  "#{col_red}YES#{reset_color}"

              else

                puts "\t#{key_color}Delete on Termination:#{reset_color} " +
                  "#{col_green}NO#{reset_color}"

              end

              puts "\t#{key_color}Attach Time:#{reset_color} #{vol_obj.attached_at}"
              puts "\t#{key_color}Creation Time:#{reset_color} #{vol_obj.created_at}"

              if (vol_obj.snapshot_id != nil)

                snap_obj = conn.snapshots.get(vol_obj.snapshot_id)

                print "\t#{key_color}Snapshot ID:#{reset_color} #{vol_obj.snapshot_id}"

                if (defined?snap_obj.created_at)

                  puts " (Created: #{snap_obj.created_at})"

                end

                if (defined?snap_obj.tags) && (snap_obj.tags != {})

                  puts "\t\t#{key_color}Tags:#{reset_color}"

                  snap_obj.tags.each do |snap_tag,snap_tag_value|

                    puts "\t\t\t#{key_color}#{snap_tag}:#{reset_color} #{snap_tag_value}"

                  end

                end

              end

              if (vol_obj.state != "in-use")

                puts "\t#{key_color}State:#{reset_color} #{vol_obj.state}"

              end

              if (vol['status'] == "attached")

                status_color = col_green

              else

                status_color = col_red

              end

              puts "\t#{key_color}Status:#{reset_color} #{status_color}#{vol['status']}#{reset_color}"

              if (vol_obj.tags != {})

                puts "\t#{key_color}Tags:#{reset_color}"

                vol_obj.tags.each do |vol_tag,vol_tag_value|

                  puts "\t\t#{key_color}#{vol_tag}:#{reset_color} #{vol_tag_value}"

                end

              end

              if (vol != instance.block_device_mapping.last)

                puts "\t---------------------------------------"

              end

            end

          when :client_token

            if (instance.client_token != nil)

              puts "#{key_color}Client Token:#{reset_color} #{instance.client_token}"

            elsif $DEBUG

              puts "#{key_color}Client Token:#{reset_color} N/A"

            end

          when :dns_name

            puts "#{key_color}DNS Name:#{reset_color} #{instance.dns_name}"

          when :groups

            instance.groups.each do |group_id|

              group = conn.security_groups.get(group_id)

              if (group != nil)

                puts "#{key_color}Security Group:#{reset_color} #{group.name}"
                puts "\t#{key_color}Description:#{reset_color} #{group.description}"
                puts "\t#{key_color}ID:#{reset_color} #{group.group_id}"

              end

              break if group != nil

            end

          when :flavor_id
            
            instance_flavor = conn.flavors.get(instance.flavor_id)

            puts "#{key_color}Flavor:#{reset_color} #{instance_flavor.id}"

            puts "\t#{key_color}Name:#{reset_color} #{instance_flavor.name}"
            puts "\t#{key_color}Architecture:#{reset_color} #{instance_flavor.bits} bit"
            puts "\t#{key_color}Cores:#{reset_color} #{instance_flavor.cores}"
            puts "\t#{key_color}Instance Storage (in /mnt):#{reset_color} #{instance_flavor.disk} GB"
            puts "\t#{key_color}RAM:#{reset_color} #{instance_flavor.ram} MB"

          when :image_id

            puts "#{key_color}Image ID:#{reset_color} #{instance.image_id}"
            
            image_obj = conn.images.get(instance.image_id)

            if (defined?image_obj.name)
              
              puts "\t#{key_color}Name:#{reset_color} #{image_obj.name}"

            end

            if (defined?image_obj.description)

              puts "\t#{key_color}Description:#{reset_color} #{image_obj.description}"

            end

            if (defined?image_obj.location)
              
              puts "\t#{key_color}Location:#{reset_color} #{image_obj.location}"

            end

            if (defined?image_obj.architecture)
              
              puts "\t#{key_color}Arch:#{reset_color} #{image_obj.architecture}"

            end
            
            if (defined?image_obj.tags) && (image_obj.tags != {})

              puts "\t#{key_color}Tags:#{reset_color}"

              image_obj.tags.each do |image_tag,image_tag_value|

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

            if (instance.placement_group != nil)

              puts "#{key_color}Placement Group:#{reset_color} #{instance.placement_group}"

            elsif $DEBUG

              puts "#{key_color}Placement Group:#{reset_color} N/A"

            end

          when :platform

            if (instance.platform != nil)

              puts "#{key_color}Platform:#{reset_color} #{instance.platform}"

            elsif $DEBUG

              puts "#{key_color}Platform:#{reset_color} N/A"

            end

          when :product_codes

            if (instance.product_codes.count > 0)

              puts "#{key_color}Product Codes:#{reset_color} #{instance.product_codes.join(',')}"

            elsif $DEBUG

              puts "#{key_color}Product Codes:#{reset_color} N/A"

            end

          when :private_dns_name

            puts "#{key_color}Private DNS Name:#{reset_color} #{instance.private_dns_name}"

          when :private_ip_address

            puts "#{key_color}Private IP Address:#{reset_color} #{instance.private_ip_address}"

          when :public_ip_address

            if conn.addresses.get(instance.public_ip_address)

              puts "#{key_color}Public IP Address:#{reset_color} " +
                "#{instance.public_ip_address} (#{col_green}STATIC#{reset_color})"

            else

              puts "#{key_color}Public IP Address:#{reset_color} " +
                "#{instance.public_ip_address} (#{col_red}DYNAMIC#{reset_color})"

            end

          when :ramdisk_id

            if (instance.ramdisk_id != nil)

              puts "#{key_color}Ramdisk ID:#{reset_color} #{instance.ramdisk_id}"

            elsif $DEBUG

              puts "#{key_color}Ramdisk ID:#{reset_color} N/A"

            end

          when :reason

            if (instance.reason != nil)

              puts "#{key_color}State Reason:#{reset_color} #{instance.reason}"

            elsif $DEBUG

              puts "#{key_color}State Reason:#{reset_color} N/A"

            end

          when :root_device_name

            if (instance.root_device_name != nil)

              puts "#{key_color}Root Device Name:#{reset_color} #{instance.root_device_name}"

            elsif $DEBUG

              puts "#{key_color}Root Device Name:#{reset_color} N/A"

            end

          when :root_device_type

            if (instance.root_device_type != nil)

              puts "#{key_color}Root Device Type:#{reset_color} #{instance.root_device_type}"

            elsif $DEBUG

              puts "#{key_color}Root Device Name:#{reset_color} N/A"

            end

          when :security_group_ids

            if (instance.security_group_ids != nil)

              puts "#{key_color}Security Group IDs:#{reset_color} #{instance.security_group_ids}"

            elsif $DEBUG

              puts "#{key_color}Security Group IDs:#{reset_color} N/A"

            end

          when :state

            state_color = get_state_color(instance.state)

            puts "#{key_color}State:#{reset_color} #{state_color}#{instance.state}#{reset_color}"

          when :state_reason

            if (instance.state_reason != {})

              puts "#{key_color}State Reason Code:#{reset_color} #{instance.state_reason["Code"]}"

            elsif $DEBUG

              puts "#{key_color}State Reason Code:#{reset_color} N/A"

            end

          when :subnet_id

            if (instance.subnet_id != nil)

              puts "#{key_color}Subnet ID:#{reset_color} #{instance.subnet_id}"

            elsif $DEBUG

              puts "#{key_color}Subnet ID:#{reset_color} N/A"

            end

          when :tenancy

            puts "#{key_color}Tenancy:#{reset_color} #{instance.tenancy}"

          when :tags

            if (instance.tags.count > 0)

              puts "#{key_color}Tags:#{reset_color} "

              instance.tags.each do |tag,value|

                puts "\t#{key_color}#{tag}:#{reset_color} #{value}"

              end

            else

              puts "#{key_color}Tags:#{reset_color} None"

            end

          when :user_data

            if (instance.user_data != nil)

              puts "#{key_color}User Data:#{reset_color} #{instance.user_data}"

            elsif $DEBUG

              puts "#{key_color}User Data:#{reset_color} N/A"

            end

          when :vpc_id

            if (instance.vpc_id != nil)

              puts "#{key_color}VPC ID:#{reset_color} #{instance.vpc_id}"

            elsif $DEBUG

              puts "#{key_color}VPC ID: #{reset_color} N/A"

            end

          else

            if instance.respond_to? :instance_attribute

              puts "#{key_color}#{instance_attribute.to_s}:#{reset_color} #{instance.instance_attribute}"

            else
              
              puts "#{key_color}#{instance_attribute.to_s}:#{reset_color} <NULL>"

            end

          end

        end

        if instance.instance_initiated_shutdown_behavior == nil
          
          puts "#{key_color}Shutdown Behavior:#{reset_color} Do nothing"

        else

          puts "#{key_color}Shutdown Behavior:#{reset_color} " +
            "#{instance.instance_initiated_shutdown_behavior}"

        end

        if (instance_id != instance_ids.last)

          puts "------------------------------------------------------------------------------------"

        end

      end
  		
  	end
  	
  	def initialize()

      if (ARGV[0] == "") || (ARGV[0] == nil)

        puts "Please specify a search term (Host Name or Instance ID)"
        exit 1

      end

      args = ARGV

      if args.include?("-s") || args.include?("--short")

        args.delete("-s")
        args.delete("--short")

  		  describe_instance_short(args)

      else

  		  describe_instance(args)

      end
  	

  		
  	end
  	
  end

end