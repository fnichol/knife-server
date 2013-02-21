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

require 'chef/knife/server_bootstrap_base'

class Chef
  class Knife
    class ServerBootstrapEc2 < Knife

      banner "knife server bootstrap ec2 (options)"

      include Knife::ServerBootstrapBase

      deps do
        require 'knife/server/ssh'
        require 'knife/server/credentials'
        require 'knife/server/ec2_security_group'

        begin
          require 'chef/knife/ec2_server_create'
          require 'fog'
          Chef::Knife::Ec2ServerCreate.load_deps

          current_options = self.options
          self.options = Chef::Knife::Ec2ServerCreate.options.dup
          self.options.merge!(current_options)
        rescue LoadError => ex
          ui.error [
            "Knife plugin knife-ec2 could not be loaded.",
            "Please add the knife-ec2 gem to your Gemfile or",
            "install the gem manually with `gem install knife-ec2'.",
            "(#{ex.message})"
          ].join(" ")
          exit 1
        end
      end

      option :security_groups,
        :short => "-G X,Y,Z",
        :long => "--groups X,Y,Z",
        :description => "The security groups for this server",
        :default => ["infrastructure"],
        :proc => Proc.new { |groups| groups.split(',') }

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
        Chef::Knife::Ec2ServerCreate.options.keys.each do |attr|
          bootstrap.config[attr] = config_val(attr)
        end
        [:verbosity].each do |attr|
          bootstrap.config[attr] = config_val(attr)
        end
        bootstrap.config[:tags] = bootstrap_tags
        bootstrap.config[:distro] = bootstrap_distro
        bootstrap
      end

      def ec2_connection
        @ec2_connection ||= Fog::Compute.new(
          :provider => 'AWS',
          :aws_access_key_id => config_val(:aws_access_key_id),
          :aws_secret_access_key => config_val(:aws_secret_access_key),
          :region => config_val(:region)
        )
      end

      def server_dns_name
        server = ec2_connection.servers.find do |s|
          s.state == "running" &&
            s.tags['Name'] == config_val(:chef_node_name) &&
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

      def config_security_group(name = nil)
        name = config_val(:security_groups).first if name.nil?

        ::Knife::Server::Ec2SecurityGroup.new(ec2_connection, ui).
          configure_chef_server_group(name, :description => "#{name} group")
      end

      def bootstrap_tags
        Hash[Array(config_val(:tags)).map { |t| t.split('=') }].
          merge({"Role" => "chef_server"}).map { |k,v| "#{k}=#{v}" }
      end

      def ssh_connection
        opts = {
          :host => server_dns_name,
          :user => config_val(:ssh_user),
          :port => config_val(:ssh_port),
          :keys => [config_val(:identity_file)].compact
        }
        if config_val(:host_key_verify) == false
          opts[:user_known_hosts_file] = "/dev/null"
          opts[:paranoid] = false
        end

        ::Knife::Server::SSH.new(opts)
      end
    end
  end
end
