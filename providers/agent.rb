use_inline_resources

def whyrun_supported?
  true
end

def up_to_date
  ![0, nil].include?(/#{current_version}/ =~ upstream_version)
end

def current_version
  case node['platform_family']
  when 'rhel'
    running_version = `rpm -q codedeploy-agent`
    running_version.strip
  when 'debian'
    running_agent = `dpkg -s codedeploy-agent`
    running_agent_info = running_agent.split
    version_index = running_agent_info.index('Version:')
    if version_index.nil?
      nil
    else
      running_agent_info[version_index + 1]
    end
  else
    Chef::Application.fatal!("#{node['platform_family']} not supported")
  end
end

def upstream_version
  uri = URI.parse(version_url)
  response = Net::HTTP.get_response(uri)
  versions = JSON.parse(response.body)

  package_type = {
    'debian' => 'deb',
    'rhel' => 'rpm',
    'windows' => 'msi'
  }[node['platform_family']]

  versions[package_type]
end

def region
  if node.key?('ec2')
    node['ec2']['placement_availability_zone'][0..-2]
  else
    'us-east-1'
  end
end

def bucket
  "aws-codedeploy-#{region}"
end

def service_name
  'codedeploy-agent'
end

def package_name
  'codedeploy-agent'
end

def installer_url
  new_resource.installer_url || "https://#{bucket}.s3.amazonaws.com/latest/install"
end

def version_url
  new_resource.version_url || "https://#{bucket}.s3.amazonaws.com/latest/VERSION"
end

def installer_path
  "#{Chef::Config[:file_cache_path]}/code_deploy_installer"
end

def install_ruby
  case node['platform_family']
  when 'debian'
    package 'ruby2.0'
  when 'rhel'
    package 'ruby'
  end
end

def install_code_deploy_agent
  install_ruby

  proxy_arg = "--proxy #{new_resource.http_proxy}" unless new_resource.http_proxy.nil?

  install_command = [installer_path, proxy_arg, 'auto'].compact.join(' ')

  remote_file installer_path do
    source installer_url
    mode '0755'
    not_if { up_to_date }
  end

  execute install_command do
    not_if { up_to_date }
  end

  file '/etc/cron.d/codedeploy-agent-update' do
    action :delete
  end
end

action :install do
  install_code_deploy_agent

  service service_name do
    action [:disable, :stop]
  end
end

action :install_and_start do
  install_code_deploy_agent

  service service_name do
    action [:enable, :start]
  end
end

action :uninstall do
  case node['platform_family']
  when 'debian'
    dpkg_package 'codedeploy-agent' do
      action :purge
    end
  else
    package package_name do
      action :remove
    end
  end
end

%i(
  disable
  enable
  restart
  start
  stop
).each do |a|
  action a do
    service service_name do
      action a
    end
  end
end
