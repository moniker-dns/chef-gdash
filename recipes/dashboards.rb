include_recipe 'gdash'

# gdash_dashboard 'Graphite Metrics' do
#   category 'Graphite'
#   description 'Graphite Metrics'
# end

# gdash_dashboard_component 'metrics_received' do
#   dashboard_name 'Graphite Metrics'
#   dashboard_category 'Graphite'
#   vtitle 'Items'
#   fields(
#     :received => {
#       :data => 'carbon.*.*.metricsReceived',
#       :alias => 'Metrics Received'
#     }
#   )
# end

# gdash_dashboard_component 'cpu' do
#   dashboard_name 'Graphite Metrics'
#   dashboard_category 'Graphite'
#   fields(
#     :cpu => {
#       :data => 'carbon.*.*.cpuUsage',
#       :alias => 'CPU Usage'
#     }
#   )
# end

# gdash_dashboard_component 'memory' do
#   dashboard_name 'Graphite Metrics'
#   dashboard_category 'Graphite'

#   fields(
#     :memory => {
#       :data => 'carbon.*.*.memUsage',
#       :alias => 'Memory Usage'
#     }
#   )
# end

ALL_ROLES = [
  'chef',
  'graphite',
  'graylog',
  'haproxy',
  'monikerapi',
  'monikercentral',
  'percona',
  'powerdns',
  'rabbitmq'
]


ALL_ROLES.each do |role|
  role_members = search("node", "role:#{role} AND chef_environment:#{node.chef_environment}") || []
  role_members << node if node.run_list.roles.include?(role)

  role_members = role_members.sort_by { |m| m['hostname'] }

  ############
  # Disk Usage
  ############
  gdash_dashboard 'Disk' do
    category role.capitalize
    description "#{role.capitalize} Disk Metrics"
  end

  %w{root ephemeral0}.each do |device|
    gdash_dashboard_component "#{role}_disk_usage_#{device}" do
      dashboard_name 'Disk'
      dashboard_category role.capitalize

      title "#{role.capitalize} Disk Usage % / #{device}"
      vtitle '% Used'

      ymin 0
      ymax 100

      _fields = {}

      role_members.each do |member|
        _fields[member['hostname']] = {
          :alias => member['hostname'],
          :data => "asPercent(servers.#{member['hostname']}.diskspace.#{device}.byte_used,sumSeries(servers.#{member['hostname']}.diskspace.#{device}.byte_free, servers.#{member['hostname']}.diskspace.#{device}.byte_used))",
          :cacti_style => true
        }
      end

      fields(_fields)
    end
  end

  #####
  # CPU
  #####
  gdash_dashboard 'CPU' do
    category role.capitalize
    description "#{role.capitalize} CPU Metrics"
  end

  %w{01 05 15}.each do |period|
    gdash_dashboard_component "#{role}_load_average_#{period}" do
      dashboard_name 'CPU'
      dashboard_category role.capitalize

      title "#{role.capitalize} Load Average (#{period} min)"
      vtitle 'Load'

      _fields = {}

      role_members.each do |member|
        _fields[member['hostname']] = {
          :alias => member['hostname'],
          :data => "servers.#{member['hostname']}.loadavg.#{period}",
          :cacti_style => true
        }
      end

      fields(_fields)
    end
  end

  ########
  # Memory
  ########
  gdash_dashboard 'Memory' do
    category role.capitalize
    description "#{role.capitalize} Memory Metrics"
  end

  role_members.each do |member|
    gdash_dashboard_component "#{role}_memory_#{member['hostname']}" do
      dashboard_name 'Memory'
      dashboard_category role.capitalize

      title "#{member['hostname']} Memory Usage"

      fields(
        'MemTotal' => {
          :alias => 'MemTotal',
          :data => "servers.#{member['hostname']}.memory.MemTotal"
        },
        'MemFree' => {
          :alias => 'MemFree',
          :data => "stacked(servers.#{member['hostname']}.memory.MemFree)"
        },
        'Buffers' => {
          :alias => 'Buffers',
          :data => "stacked(servers.#{member['hostname']}.memory.Buffers)"
        },
        'Cached' => {
          :alias => 'Cached',
          :data => "stacked(servers.#{member['hostname']}.memory.Cached)"
        },
        'Dirty' => {
          :alias => 'Dirty',
          :data => "stacked(servers.#{member['hostname']}.memory.Dirty)"
        }
      )
    end
  end

  if role == 'graphite'
    ##########
    # Graphite
    ##########
    gdash_dashboard 'Carbon' do
      category role.capitalize
      description "#{role.capitalize} Carbon Metrics"
    end

    role_members.each do |member|
      gdash_dashboard_component "#{role}_carbon_metrics_#{member['hostname']}" do
        dashboard_name 'Carbon'
        dashboard_category role.capitalize

        title "#{member['hostname']} Carbon Metrics"

        fields(
          'Metrics Received' => {
            :alias => 'Metrics Received',
            :data => "carbon.agents.#{member['hostname']}-*.metricsReceived"
          },
          'Committed Points' => {
            :alias => 'Committed Points',
            :data => "carbon.agents.#{member['hostname']}-*.committedPoints"
          },
          'Update Operations' => {
            :alias => 'Update Operations',
            :data => "carbon.agents.#{member['hostname']}-*.updateOperations"
          },
          'Creates' => {
            :alias => 'Creates',
            :data => "carbon.agents.#{member['hostname']}-*.creates"
          }
        )
      end
    end
  end

  if role == 'monikerapi'
    ########
    # Nginx
    ########
    gdash_dashboard 'Nginx' do
      category role.capitalize
      description "#{role.capitalize} Nginx Metrics"
    end

    role_members.each do |member|
      gdash_dashboard_component "#{role}_active_connections_#{member['hostname']}" do
        dashboard_name 'Nginx'
        dashboard_category role.capitalize

        title "#{member['hostname']} Active Connections"

        area :stacked

        fields(
          'Reading' => {
            :alias => 'Reading',
            :data => "servers.#{member['hostname']}.nginx.act_reads"
          },
          'Writing' => {
            :alias => 'Writing',
            :data => "servers.#{member['hostname']}.nginx.act_writes"
          },
          'Waiting' => {
            :alias => 'Waiting',
            :data => "servers.#{member['hostname']}.nginx.act_waits"
          }
        )
      end
    end
  end

  if role == 'powerdns'
    ##########
    # PowerDNS
    ##########
    gdash_dashboard 'Powerdns' do
      category role.capitalize
      description "#{role.capitalize} PowerDNS Metrics"
    end

    # Combined
    gdash_dashboard_component "#{role}_queries_combined" do
      dashboard_name 'Powerdns'
      dashboard_category role.capitalize

      title "Combined Queries"

      area :stacked

      _fields = {}

      role_members.each do |member|
        _fields["#{member['hostname']}"] = {
          :alias => "#{member['hostname']}",
          :data => "sumSeries(servers.#{member['hostname']}.powerdns.udp-queries, servers.#{member['hostname']}.powerdns.tcp-queries)"
        }
      end

      fields(_fields)
    end

    # Per Member
    role_members.each do |member|
      gdash_dashboard_component "#{role}_queries_#{member['hostname']}" do
        dashboard_name 'Powerdns'
        dashboard_category role.capitalize

        title "#{member['hostname']} Queries"

        area :stacked

        fields(
          'UDP' => {
            :alias => 'UDP',
            :data => "servers.#{member['hostname']}.powerdns.udp-queries"
          },
          'TCP' => {
            :alias => 'TCP',
            :data => "servers.#{member['hostname']}.powerdns.tcp-queries"
          }
        )
      end
    end
  end
end
