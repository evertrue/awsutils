require 'optimist'
require 'aws-sdk-ec2'
require 'highline'
require 'colorize'

GROUPS_MAX_LENGTH = 96

module AwsUtils
  class Ec2ListMachines
    def run
      servers_sorted = formatted_servers.sort_by { |server| server.fetch(opts[:sort].to_sym, '') }

      # Clear all formatting
      printf "\033[0m"

      items = bold_header + servers_sorted.map do |server|
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

    private

    def connect
      @connect ||= Aws::EC2::Client.new
    end

    def servers
      return connect.describe_instances.reservations.map(&:instances).flatten unless opts[:search]

      connect.describe_instances.reservations.map(&:instances).flatten.select do |i|
        (name_tag = i.tags.find { |t| t.key == 'Name' }) &&
          name_tag.value =~ /.*#{opts[:search]}.*/
      end
    end

    def include_terminated?
      opts[:terminated] || opts[:state] == 'terminated'
    end

    # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def include_server?(server)
      return false if (opts[:state] && server.state.name != opts[:state]) ||
                      (opts[:type] && server.instance_type != opts[:type]) ||
                      (opts[:zone] && server.placement.availability_zone != opts[:zone]) ||
                      (server.state.name == 'terminated' && !include_terminated?)

      true
    end
    # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def formatted_servers
      static_ips = connect.describe_addresses.addresses.map(&:public_ip)

      servers.select { |server| include_server? server }.map do |server|
        o = {
          date: server.launch_time.to_s,
          az: server.placement.availability_zone,
          id: server.instance_id,
          subnet: [server.subnet_id, "(#{subnet_name[server.subnet_id]})"].join(' '),
          priv_ip: server.private_ip_address,
          type: server.instance_type,
          vpc: server.vpc_id,
          state: opts[:csv] ? server.state.name : colorize_state(server.state.name).bold
        }

        if opts[:groups]
          groups_string =
            server.security_groupserver.map { |g| "#{g.group_id} (#{g.group_name})" }.join(', ')

          # Shorten the groups string to a manageable length
          unless (opts[:csv] || opts[:all_groups]) && groups_string.length > GROUPS_MAX_LENGTH
            groups_string = groups_string[0..GROUPS_MAX_LENGTH] + '...'
          end

          o[:groups] = groups_string
        end

        if server.vpc_id && opts[:vpc]
          o[:vpc] = [server.vpc_id, "(#{vpc_name[server.vpc_id]})"].join(' ')
        end

        if server.public_ip_address
          static_ip = static_ips.include?(server.public_ip_address) ? '(S)' : '(D)'
          o[:pub_ip] = [server.public_ip_address, static_ip].join(' ')
        end

        # Always include the name tag regardless of cli args (for searching)
        (opts[:tags] | %w[tag_Name]).each do |tag|
          next unless (k = server.tags.find { |t| t.key == tag })

          o["tag_#{tag}".to_sym] = k.value
        end

        o
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

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

      o.merge!(
        az: 'AZ',
        subnet: 'Subnet',
        priv_ip: 'Private IP'
      )

      o[:groups] = 'Security Groups' if opts[:groups]
      o[:vpc] = 'VPC' if opts[:vpc]
      o[:created] = 'Created' if opts[:dates]

      o.merge!(
        type: 'Type',
        state: 'State',
        pub_ip: 'Public IP'
      )

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

    def bold_header
      columns.values.each_with_index.map do |v, i|
        if i.zero?
          "\033[1m#{v}"
        elsif i == columns.count - 1
          "#{v}\033[0m"
        else
          v
        end
      end
    end

    def opts
      @opts ||= begin
        opts = Optimist.options do
          opt :sort, 'Sort order', short: 's', default: 'tag_Name'
          opt :tags, 'Tags to display', short: 'T', default: %w[Name]
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
    rescue Interrupt
      puts 'Interrupted by user (SIGINT, Ctrl+C, etc.)'
    end
  end
end

# AwsUtils::Ec2ListMachines.new.run
