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
    class ServerBootstrapStandalone < Knife

      include Knife::ServerBootstrapBase

      deps do
        require 'knife/server/ssh'
        require 'knife/server/credentials'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife server bootstrap standalone (options)"

      option :host,
        :short => "-H FQDN_OR_IP",
        :long => "--host FQDN_OR_IP",
        :description => "Hostname or IP address of host to bootstrap"

      option :ssh_password,
        :short => "-P PASSWORD",
        :long => "--ssh-password PASSWORD",
        :description => "The ssh password"

      def run
        validate!
        check_ssh_connection
        standalone_bootstrap.run
        fetch_validation_key
        create_root_client
        install_client_key
      end

      def standalone_bootstrap(platform=determine_platform)
        ENV['WEBUI_PASSWORD'] = config[:webui_password]
        ENV['AMQP_PASSWORD'] = config[:amqp_password]
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [ config[:host] ]
        [ :chef_node_name, :ssh_user, :ssh_password, :ssh_port, :identity_file
        ].each { |attr| bootstrap.config[attr] = config[attr] }
        bootstrap.config[:distro] = platform || bootstrap_distro
        bootstrap.config[:use_sudo] = true unless config[:ssh_user] == "root"
        bootstrap
      end

      private

      def validate!
        if config[:chef_node_name].nil?
          ui.error "You did not provide a valid --node-name value."
          exit 1
        end
        if config[:host].nil?
          ui.error "You did not provide a valid --host value."
          exit 1
        end
      end

      def check_ssh_connection
        ssh_connection.exec! "hostname -f"
      rescue Net::SSH::AuthenticationFailed
        ui.warn("Failed to authenticate #{config[:ssh_user]} - " +
                "trying password auth")
        config[:ssh_password] = ui.ask(
          "Enter password for #{config[:ssh_user]}@#{config[:host]}: "
        ) { |q| q.echo = false }
      end

      def ssh_connection
        ::Knife::Server::SSH.new(
          :host => config[:host],
          :user => config[:ssh_user],
          :password => config[:ssh_password],
          :port => config[:ssh_port],
          :keys => [config[:identity_file]].compact
        )
      end
    end
  end
end
