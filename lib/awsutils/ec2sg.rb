require 'fog/aws'

module AwsUtils
  class Ec2SecurityGroup
    def connection
      @connection ||= Fog::Compute::AWS.new
    end

    def references(search_string)
      search =
        if search_string =~ /^sg-/
          {
            id: search_string,
            name: groups.find { |gr| gr.group_id == search_string }.name
          }
        else
          {
            id: groups.find { |gr| gr.name == search_string }.group_id,
            name: search_string
          }
        end

      groups.each_with_object({}) do |grp, m|
        permission_references = grp.ip_permissions.select do |ip_perm|
          ip_perm['groups'].find do |pair|
            pair['groupId'] == search[:id] ||
              pair['groupName'] == search[:name]
          end
        end

        next if permission_references.empty?

        m[grp.name] = { 'groupId' => grp.group_id }
        m[grp.name]['references'] = permission_references.map do |pr|
          {
            'groupId' => grp.group_id,
            'ipProtocol' => pr['ipProtocol'],
            'fromPort' => pr['fromPort'],
            'toPort' => pr['toPort']
          }
        end
      end
    end

    def groups
      @groups ||= connection.security_groups
    end

    def assigned?
      servers_using_group = connection.servers.map do |server|
        next unless server.state != 'terminated' &&
                    server.groups.include?(@opts[:security_group])
        server.tags['Name'] ? server.tags['Name'] : server.id
      end.compact

      return false unless servers_using_group.empty?
      print 'The following servers are still using this group: '
      puts servers_using_group.join(',')

      true
    end

    def exist?
      current_groups.include?(@opts[:security_group])
    end

    def current_groups
      @current_groups ||= begin
        connection.security_groups.map { |g| [g.name, g.group_id] }.flatten.uniq
      end
    end
  end
end
