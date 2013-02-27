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

      banner "knife server bootstrap standalone (options)"

      include Knife::ServerBootstrapBase

      deps do
        require 'knife/server/ssh'
        require 'knife/server/credentials'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps

        current_options = self.options
        self.options = Chef::Knife::Bootstrap.options.dup
        self.options.merge!(current_options)
      end

      option :host,
        :short => "-H FQDN_OR_IP",
        :long => "--host FQDN_OR_IP",
        :description => "Hostname or IP address of host to bootstrap"

      def run
        validate!
        check_ssh_connection
        standalone_bootstrap.run
        fetch_validation_key
        create_root_client
        install_client_key
      end

      def standalone_bootstrap
        ENV['WEBUI_PASSWORD'] = config[:webui_password]
        ENV['AMQP_PASSWORD'] = config[:amqp_password]
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [ config[:host] ]
        Chef::Knife::Bootstrap.options.keys.each do |attr|
          bootstrap.config[attr] = config_val(attr)
        end
        [:verbosity].each do |attr|
          bootstrap.config[attr] = config_val(attr)
        end
        bootstrap.config[:distro] = bootstrap_distro
        bootstrap.config[:use_sudo] = true unless config_val(:ssh_user) == "root"
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
        ui.warn("Failed to authenticate #{config_val(:ssh_user)} - " +
                "trying password auth")
        config[:ssh_password] = ui.ask(
          "Enter password for #{config_val(:ssh_user)}@#{config_val(:host)}: "
        ) { |q| q.echo = false }
      end

      def ssh_connection
        opts = {
          :host => config_val(:host),
          :user => config_val(:ssh_user),
          :password => config_val(:ssh_password),
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
