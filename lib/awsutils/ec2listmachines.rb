require 'optimist'
require 'aws-sdk-ec2'
require 'highline'
require 'colorize'

GROUPS_MAX_LENGTH = 96

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
  class Ec2ListMachines
    def connect
      @connect = Aws::EC2::Client.new
      if $DEBUG
        puts 'Inspect connection result:'
        puts connect.inspect
      end

      @connect
    end

    def get_servers
      static_ips = connect.describe_addresses.addresses.map(&:public_ip)

      group_map = connect.describe_security_groups.security_groups.each_with_object({}) do |g, m|
        m[g.group_name] = g.group_id
      end

      servers =
        if opts[:search]
          connect.describe_instances.reservations.map { |r| r.instances }.flatten.select do |i|
            if (name_tag = i.tags.find { |t| t.key == 'Name' })
              name_tag.value =~ /.*#{opts[:search]}.*/
            else
              false
            end
          end
        else
          connect.describe_instances.reservations.map { |r| r.instances }.flatten
        end

      servers.each_with_object([]) do |s, m|
        next unless (opts[:state].nil? || (s.state.name == opts[:state])) &&
          (
            (opts[:terminated] == true) ||
            (s.state.name != 'terminated') ||
            (opts[:state] == 'terminated')
          ) &&
          (opts[:type].nil? || (s.instance_type == opts[:type])) &&
          (opts[:zone].nil? || (s.placement.availability_zone == opts[:zone]))

        if s.public_ip_address
          static_ip = static_ips.include?(s.public_ip_address) ? '(S)' : '(D)'
        end

        o = {
          date: s.launch_time.to_s,
          az: s.placement.availability_zone,
          id: s.instance_id,
          subnet: [s.subnet_id, "(#{subnet_name[s.subnet_id]})"].join(' '),
          priv_ip: s.private_ip_address,
          type: s.instance_type,
          vpc: s.vpc_id,
          state: opts[:csv] ? s.state.name : colorize_state(s.state.name).bold
        }

        if opts[:groups]
          groups_string = s.security_groups.map { |g| "#{g.group_id} (#{g.group_name})" }.join(', ')

          # Shorten the groups string to a manageable length
          unless opts[:csv] || opts[:all_groups]
            groups_string = groups_string[0..GROUPS_MAX_LENGTH] + '...' if groups_string.length > GROUPS_MAX_LENGTH
          end

          o[:groups] = groups_string
        end

        o[:vpc] = [s.vpc_id, "(#{vpc_name[s.vpc_id]})"].join(' ') if s.vpc_id && opts[:vpc]
        o[:pub_ip] = [s.public_ip_address, static_ip].join(' ') if s.public_ip_address

        serv = s

        opts[:tags].each do |tag|
          next unless (k = s.tags.find { |t| t.key == tag })
          o["tag_#{tag}".to_sym] = k.value
        end

        # Always include the name tag anyway for searching
        if !o[:tag_Name] && (n = s.tags.find { |t| t.key == 'Name' })
          o[:tag_Name] = n.value
        end

        m << o
      end
    end

    def vpc_name
      @vpc_name ||= connect.describe_vpcs.vpcs.each_with_object({}) do |v, m|
        next unless (tag = v.tags.find { |t| t.key == 'Name' })
        m[v.vpc_id] = tag.value
      end
    end

    def subnet_name
      @subnet_name ||= connect.describe_subnets.subnets.each_with_object({}) do |s, m|
        next unless (tag = s.tags.find { |t| t.key == 'Name' })
        m[s.subnet_id] = tag.value
      end
    end

    def columns
      # This method also determines this display order

      o = { id: 'ID' }

      o.merge!({
        az: 'AZ',
        subnet: 'Subnet',
        priv_ip: 'Private IP'
      })

      o[:groups] = 'Security Groups' if opts[:groups]
      o[:vpc] = 'VPC' if opts[:vpc]
      o[:created] = 'Created' if opts[:dates]

      o.merge!({
        type: 'Type',
        state: 'State',
        pub_ip: 'Public IP'
      })

      opts[:tags].each { |t| o["tag_#{t}".to_sym] = "Tag:#{t}" }

      o
    end

    def colorize_state(state)
      case state
      when 'running'
        state.colorize :green
      when 'stopped'
        state.colorize :red
      when 'starting', 'stopping'
        state.colorize :orange
      else
        state.disable_colorization = true
      end
    end

    def render_list(servers_sorted)
      # Clear all formatting
      printf "\033[0m"

      items = []

      # Bold the header line
      columns.values.each_with_index do |v, i|
        if i == 0
          items << "\033[1m#{v}"
        elsif i == columns.count - 1
          items << "#{v}\033[0m"
        else
          items << v
        end
      end

      items += servers_sorted.map do |server|
        columns.keys.map do |col|
          # Set an empty string here so that CSV ends up with the right number of cols even when
          # a field is unset
          server[col] || ''
        end
      end.flatten

      if opts[:csv]
        hl = HighLine::List.new items, cols: columns.count
        hl.row_join_string = ','
        puts hl.to_s
      else
        puts HighLine.new.list items, :uneven_columns_across, columns.count
      end
    end

    def opts
      @opts ||= begin
        opts = Optimist.options do
          opt :sort, 'Sort order', short: 's', default: 'tag_Name'
          opt :tags, 'Tags to display', short: 'T', default: %w(Name)
          opt :groups, 'Display Security Groups', default: false
          opt :state, 'State', short: 'S', type: String
          opt :type, 'Type', short: 'F', type: String
          opt :zone, 'Availability Zone', short: 'Z', type: String
          opt :csv, 'Output in CSV Format', short: 'C', default: false
          opt :dates, 'Show creation timestamp', short: 'd', default: false
          opt :terminated, 'Show terminated instances', short: 't', default: false
          opt :nocolor, 'No color', short: 'c'
          opt :vpc, 'Show VPC', default: true
          opt :all_groups, 'Display full groups lists', default: false
        end

        opts[:search] = ARGV[0] unless ARGV.empty?

        opts
      end
    end

    def run
      render_list get_servers.sort_by { |server| server.fetch(opts[:sort].to_sym, '') }
    rescue Interrupt
      puts 'Interrupted by user (SIGINT, Ctrl+C, etc.)'
    end
  end
end

# AwsUtils::Ec2ListMachines.new.run
