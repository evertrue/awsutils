require 'rubygems'
require 'trollop'
require 'fog'

gem 'fog', '>= 1.6.0'

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
      @connect = Fog::Compute.new(provider: 'AWS')
      if $DEBUG
        puts 'Inspect connection result:'
        puts connect.inspect
      end

      @connect
    end

    def get_servers(opts)
      static_ips = []
      connect.addresses.all.each do |eip|
        static_ips << eip.public_ip
      end

      group_map = {}
      connect.security_groups.map { |g| group_map[g.name] = g.group_id }

      if opts[:search]
        servers = connect.servers.select do |s|
          s.tags['Name'] =~ /.*#{opts[:search]}.*/
        end
      else
        servers = connect.servers
      end

      servers_a = []

      servers.each do |s|
        if (opts[:state].nil? || (s.state == opts[:state])) &&
          (
            (opts[:terminated] == true) ||
            (s.state != 'terminated') ||
            (opts[:state] == 'terminated')
          ) &&
          (opts[:flavor].nil? || (s.flavor_id == opts[:flavor])) &&
          (opts[:role].nil? || (s.tags['Role'] == opts[:role])) &&
          (opts[:zone].nil? || (s.availability_zone.to_s == opts[:zone]))

          if s.public_ip_address.nil?
            pub_ip = ''
          else
            pub_ip = s.public_ip_address

            static_ip = static_ips.include?(pub_ip) ? '(S)' : '(D)'
          end

          role = s.tags['Role'] ? '-' : s.tags['Role']

          if s.groups.first =~ /-/
            group_to_insert = "#{group_map[s.groups.first]}/#{s.groups.first}"
          else
            group_to_insert = s.groups.first
          end

          created = s.tags['created_on'] ||= s.created_at

          servers_a << {
            name: s.tags['Name'].to_s,
            date: created.to_s,
            role: role.to_s,
            az: s.availability_zone.to_s,
            id: s.id,
            group: group_to_insert,
            pub_ip: pub_ip,
            static_ip: static_ip,
            flavor: s.flavor_id,
            state: s.state
          }

        end
      end

      servers_a
    end

    def sort_servers(servers_a, sort_col)
      case sort_col
      when 'role'
        servers_a.sort_by { |a| a[:role] }
      when 'az'
        servers_a.sort_by { |a| a[:az] }
      when 'name'
        servers_a.sort_by { |a| a[:name] }
      when 'id'
        servers_a.sort_by { |a| a[:id] }
      when 'group'
        servers_a.sort_by { |a| a[:group] }
      when 'flavor'
        servers_a.sort_by { |a| a[:flavor] }
      when 'state'
        servers_a.sort_by { |a| a[:state] }
      when 'ip'
        servers_a.sort_by { |a| a[:pub_ip] }
      when 'static'
        servers_a.sort_by { |a| a[:static_ip] }
      when 'date'
        servers_a.sort_by { |a| a[:date] }
      else
        servers_a.sort_by { |a| a[:name] }
      end
    end

    def get_longest_server_name(servers_sorted)
      server_names = []
      servers_sorted.each do |server|
        server_names << server[:name]
      end

      server_names.longest.length + 1
    end

    def print_headers(csv_opt, servers_sorted, longest_server_name, show_dates)
      if csv_opt == true
        if show_dates
          printf(
            "%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
            'Name',
            'Created',
            'Role',
            'AZ',
            'ID',
            'Sec Group',
            'Public IP,(S/D)',
            'Flavor',
            'State'
          )
        else
          printf(
            "%s,%s,%s,%s,%s,%s,%s,%s\n",
            'Name',
            'Role',
            'AZ',
            'ID',
            'Sec Group',
            'Public IP,(S/D)',
            'Flavor',
            'State'
          )
        end
      else
        if show_dates
          printf(
            "\033[0;4m%-#{longest_server_name}s %-30s %-16s %-10s %-10s " \
              "%-24s %-19s %-10s %-7s\033[0m\n",
            'Name',
            'Created',
            'Role',
            'AZ',
            'ID',
            'Sec Group',
            'Public IP (S/D)',
            'Flavor',
            'State'
          )
        else
          printf(
            "\033[0;4m%-#{longest_server_name}s %-16s %-10s %-10s %-24s " \
              "%-19s %-10s %-7s\033[0m\n",
            'Name',
            'Role',
            'AZ',
            'ID',
            'Sec Group',
            'Public IP (S/D)',
            'Flavor',
            'State'
          )
        end
      end
    end

    def get_flavor_color(flavor)
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
    end

    def get_state_color(state)
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
    end

    def print_machine_list(servers_sorted, nocolor_opt, csv_opt, longest_server_name, show_dates)
      servers_sorted.each do |server|
        name =      server[:name]
        date =      server[:date]
        role =      server[:role]
        az =        server[:az]
        id =        server[:id]
        group =     server[:group]
        ip =        server[:pub_ip]
        static_ip = server[:static_ip]
        flavor =    server[:flavor]
        state =     server[:state]
        fcolor =    get_flavor_color(flavor)
        scolor =    get_state_color(state)

        if (nocolor_opt == false) && (csv_opt == false)
          if show_dates
            printf(
              "\033[1m%-#{longest_server_name}s\033[0m %-30s %-16s %-10s %-10s " \
                "%-24s %-19s \033[#{fcolor}m%-11s\033[#{scolor}m%-7s\033[0m\n",
              name,
              date,
              role,
              az,
              id,
              group,
              "#{ip} #{static_ip}",
              flavor,
              state
            )
          else
            printf(
              "\033[1m%-#{longest_server_name}s\033[0m %-16s %-10s %-10s " \
                "%-24s %-19s \033[#{fcolor}m%-11s\033[#{scolor}m%-7s\033[0m\n",
              name,
              role,
              az,
              id,
              group,
              "#{ip} #{static_ip}",
              flavor,
              state
            )
          end
        elsif csv_opt == true
          if show_dates
            printf(
              "%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
              name,
              date,
              role,
              az,
              id,
              group,
              "#{ip},#{static_ip}",
              flavor,
              state
            )
          else
            printf(
              "%s,%s,%s,%s,%s,%s,%s,%s\n",
              name,
              role,
              az,
              id,
              group,
              "#{ip},#{static_ip}",
              flavor,
              state
            )
          end
        else
          if show_dates
            printf(
              "%-#{longest_server_name}s %-20s %-16s %-10s %-10s %-20s %-19s %-11s%-7s\n",
              name,
              date,
              role,
              az,
              id,
              group,
              "#{ip} #{static_ip}",
              flavor,
              state
            )
          else
            printf(
              "%-#{longest_server_name}s %-16s %-10s %-10s %-20s %-19s %-11s%-7s\n",
              name,
              role,
              az,
              id,
              group,
              "#{ip} #{static_ip}",
              flavor,
              state
            )
          end
        end
      end
    end

    def print_counts(servers_sorted, opts_csv)
      flavor_data = {}
      connect.flavors.each do |f|
        flavor_data[f.id] = {
          'cores' => f.cores,
          'disk' => f.disk,
          'ram' => f.ram
        }
      end
      total_cores = 0
      total_disk = 0.0
      total_ram = 0.0

      servers_sorted.each do |s|
        total_cores += flavor_data[s[:flavor]]['cores']
        total_disk += flavor_data[s[:flavor]]['disk'].to_f
        total_ram += flavor_data[s[:flavor]]['ram'].to_f
      end

      if opts_csv
        puts "total_instances,#{servers_sorted.count}"
        puts "total_cores,#{total_cores}"
        puts "total_disk,#{total_disk}"
        puts "total_ram,#{total_ram}"
      else
        puts "\nTotals"
        puts "\tInstances: #{servers_sorted.count}"
        puts "\tCores: #{total_cores}"
        printf("\tInstance storage: %.2f TB\n", total_disk / 1024)
        printf("\tRAM: %.2f GB\n", total_ram / 1024)
      end
    end

    def list_instances(opts)
      servers = get_servers(opts)
      servers_sorted = sort_servers(servers, opts[:sort])
      longest_server_name = get_longest_server_name(servers_sorted)
      print_headers(opts[:csv], servers_sorted, longest_server_name, opts[:dates])
      print_machine_list(
        servers_sorted,
        opts[:nocolor],
        opts[:csv],
        longest_server_name,
        opts[:dates]
      )

      print_counts(servers_sorted, opts[:csv])
    end

    def parse_opts
      opts = Trollop.options do
        opt :sort, 'Sort order', short: 's', type: String
        opt :state, 'State', short: 'S', type: String
        opt :flavor, 'Flavor', short: 'F', type: String
        opt :role, 'Role', short: 'r', type: String
        opt :zone, 'Availability Zone', short: 'Z', type: String
        opt :csv, 'Output in CSV Format', short: 'C', default: false
        opt :dates, 'Show creation timestamp', short: 'd', default: false
        opt :terminated, 'Show terminated instances', short: 't', default: false
        opt :nocolor, 'No color', short: 'c'
      end

      opts[:search] = ARGV[0] unless ARGV[0].empty?

      opts
    end

    def initialize
      list_instances(parse_opts)
    rescue Interrupt
      puts 'Interrupted by user (SIGINT, Ctrl+C, etc.)'
    end
  end
end
