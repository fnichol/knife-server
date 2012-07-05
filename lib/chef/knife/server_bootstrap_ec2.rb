#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Copyright:: Copyright (c) 2012 Fletcher Nichol
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'

class Chef
  class Knife
    class ServerBootstrapEc2 < Knife

      deps do
        require 'knife/server/ec2_security_group'
        require 'knife/server/ssh'
        require 'knife/server/credentials'
        require 'chef/knife/ec2_server_create'
        require 'chef/knife/ssh'
        require 'fog'
        require 'net/ssh'
        Chef::Knife::Ec2ServerCreate.load_deps
      end

      banner "knife server bootstrap ec2 (options)"

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The name of your new Chef Server"

      option :platform,
        :short => "-P PLATFORM",
        :long => "--platform PLATFORM",
        :description => "The platform type that will be bootstrapped (debian)",
        :default => "debian"

      option :ssh_user,
        :short => "-x USERNAME",
        :long => "--ssh-user USERNAME",
        :description => "The ssh username",
        :default => "root"

      option :ssh_port,
        :short => "-p PORT",
        :long => "--ssh-port PORT",
        :description => "The ssh port",
        :default => "22",
        :proc => Proc.new { |key| Chef::Config[:knife][:ssh_port] = key }

      option :identity_file,
        :short => "-i IDENTITY_FILE",
        :long => "--identity-file IDENTITY_FILE",
        :description => "The SSH identity file used for authentication"

      option :prerelease,
        :long => "--prerelease",
        :description => "Install the pre-release chef gem"

      option :bootstrap_version,
        :long => "--bootstrap-version VERSION",
        :description => "The version of Chef to install",
        :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v }

      option :template_file,
        :long => "--template-file TEMPLATE",
        :description => "Full path to location of template to use",
        :proc => Proc.new { |t| Chef::Config[:knife][:template_file] = t },
        :default => false

      option :distro,
        :short => "-d DISTRO",
        :long => "--distro DISTRO",
        :description => "Bootstrap a distro using a template; default is 'chef-server-<platform>'"

      option :webui_password,
        :long => "--webui-password SECRET",
        :description => "Initial password for WebUI admin account, default is 'chefchef'",
        :default => "chefchef"

      option :amqp_password,
        :long => "--amqp-password SECRET",
        :description => "Initial password for AMQP, default is 'chefchef'",
        :default => "chefchef"

      # aws/ec2 options

      option :aws_access_key_id,
        :short => "-A ID",
        :long => "--aws-access-key-id KEY",
        :description => "Your AWS Access Key ID",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_access_key_id] = key }

      option :aws_secret_access_key,
        :short => "-K SECRET",
        :long => "--aws-secret-access-key SECRET",
        :description => "Your AWS API Secret Access Key",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_secret_access_key] = key }

      option :region,
        :long => "--region REGION",
        :description => "Your AWS region",
        :default => "us-east-1",
        :proc => Proc.new { |key| Chef::Config[:knife][:region] = key }

      option :ssh_key_name,
        :short => "-S KEY",
        :long => "--ssh-key KEY",
        :description => "The AWS SSH key id",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_ssh_key_id] = key }

      option :flavor,
        :short => "-f FLAVOR",
        :long => "--flavor FLAVOR",
        :description => "The flavor of server (m1.small, m1.medium, etc)",
        :proc => Proc.new { |f| Chef::Config[:knife][:flavor] = f },
        :default => "m1.small"

      option :image,
        :short => "-I IMAGE",
        :long => "--image IMAGE",
        :description => "The AMI for the server",
        :proc => Proc.new { |i| Chef::Config[:knife][:image] = i }

      option :availability_zone,
        :short => "-Z ZONE",
        :long => "--availability-zone ZONE",
        :description => "The Availability Zone",
        :default => "us-east-1b",
        :proc => Proc.new { |key| Chef::Config[:knife][:availability_zone] = key }

      option :security_groups,
        :short => "-G X,Y,Z",
        :long => "--groups X,Y,Z",
        :description => "The security groups for this server",
        :default => ["infrastructure"],
        :proc => Proc.new { |groups| groups.split(',') }

      option :tags,
        :short => "-T T=V[,T=V,...]",
        :long => "--tags Tag=Value[,Tag=Value...]",
        :description => "The tags for this server",
        :proc => Proc.new { |tags| tags.split(',') }

      option :ebs_size,
        :long => "--ebs-size SIZE",
        :description => "The size of the EBS volume in GB, for EBS-backed instances"

      option :ebs_no_delete_on_term,
        :long => "--ebs-no-delete-on-term",
        :description => "Do not delete EBS volumn on instance termination"

      def run
        validate!
        config_security_group
        ec2_bootstrap.run
        fetch_validation_key
        create_root_client
        install_client_key
      end

      def ec2_bootstrap
        ENV['WEBUI_PASSWORD'] = config[:webui_password]
        ENV['AMQP_PASSWORD'] = config[:amqp_password]
        bootstrap = Chef::Knife::Ec2ServerCreate.new
        [ :chef_node_name, :ssh_user, :ssh_port, :identity_file,
          :security_groups, :ebs_size, :webui_password, :amqp_password
        ].each { |attr| bootstrap.config[attr] = config[attr] }
        bootstrap.config[:tags] = bootstrap_tags
        bootstrap.config[:distro] = bootstrap_distro
        bootstrap
      end

      def ec2_connection
        @ec2_connection ||= Fog::Compute.new(
          :provider => 'AWS',
          :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
          :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
          :region => Chef::Config[:knife][:region]
        )
      end

      def server_dns_name
        server = ec2_connection.servers.find do |s|
          s.state == "running" &&
            s.tags['Name'] == config[:chef_node_name] &&
            s.tags['Role'] == 'chef_server'
        end

        server && server.dns_name
      end

      private

      def validate!
        if config[:chef_node_name].nil?
          ui.error "You did not provide a valid --node-name value."
          exit 1
        end
      end

      def config_security_group(name = config[:security_groups].first)
        ::Knife::Server::Ec2SecurityGroup.new(ec2_connection, ui).
          configure_chef_server_group(name, :description => "#{name} group")
      end

      def bootstrap_tags
        Hash[Array(config[:tags]).map { |t| t.split('=') }].
          merge({"Role" => "chef_server"}).map { |k,v| "#{k}=#{v}" }
      end

      def bootstrap_distro
        config[:distro] || "chef-server-#{config[:platform]}"
      end

      def credentials_client
        @credentials_client ||= ::Knife::Server::Credentials.new(
          ssh_connection, Chef::Config[:validation_key])
      end

      def fetch_validation_key
        credentials_client.install_validation_key
      end

      def install_client_key
        credentials_client.install_client_key(
          Chef::Config[:node_name], Chef::Config[:client_key])
      end

      def create_root_client
        ui.msg(credentials_client.create_root_client)
      end

      def ssh_connection
        ::Knife::Server::SSH.new(
          :host => server_dns_name,
          :user => config[:ssh_user],
          :port => config[:ssh_port]
        )
      end
    end
  end
end
