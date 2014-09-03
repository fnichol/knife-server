# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Copyright:: Copyright (c) 2013 Fletcher Nichol
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

require "chef/knife/server_bootstrap_base"

class Chef
  class Knife
    # Provisions a Linode instance and sets up an Open Source Chef Server.
    class ServerBootstrapLinode < Knife

      banner "knife server bootstrap linode (options)"

      include Knife::ServerBootstrapBase

      deps do
        require "knife/server/ssh"
        require "knife/server/credentials"

        begin
          require "chef/knife/linode_server_create"
          require "fog"
          Chef::Knife::LinodeServerCreate.load_deps

          current_options = options
          options = Chef::Knife::LinodeServerCreate.options.dup
          options.merge!(current_options)
        rescue LoadError => ex
          ui.error [
            "Knife plugin knife-linode could not be loaded.",
            "Please add the knife-linode gem to your Gemfile or",
            "install the gem manually with `gem install knife-linode'.",
            "(#{ex.message})"
          ].join(" ")
          exit 1
        end
      end

      def run
        validate!
        linode_bootstrap.run
        fetch_validation_key
        create_root_client
        install_client_key
      end

      def linode_bootstrap
        ENV["WEBUI_PASSWORD"] = config_val(:webui_password)
        ENV["AMQP_PASSWORD"] = config_val(:amqp_password)
        ENV["NO_TEST"] = "1" if config[:no_test]
        bootstrap = Chef::Knife::LinodeServerCreate.new
        Chef::Knife::LinodeServerCreate.options.keys.each do |attr|
          val = config_val(attr)
          next if val.nil?

          bootstrap.config[attr] = val
        end
        bootstrap.config[:distro] = bootstrap_distro
        bootstrap
      end

      def linode_connection
        @linode_connection ||= Fog::Compute.new(
          :provider => "Linode",
          :linode_api_key => config_val(:linode_api_key)
        )
      end

      def server_ip_address
        server = linode_connection.servers.find do |s|
          s.status == 1 && s.name == config_val(:linode_node_name)
        end

        server && server.public_ip_address
      end

      private

      def validate!
        if config[:chef_node_name].nil?
          ui.error "You did not provide a valid --node-name value."
          exit 1
        end
        if config_val(:platform) == "auto"
          ui.error "Auto platform mode cannot be used with knife-linode plugin"
          exit 1
        end
      end

      def ssh_connection
        opts = {
          :host     => server_ip_address,
          :user     => config_val(:ssh_user),
          :port     => "22",
          :keys     => [config_val(:identity_file)].compact,
          :password => config_val(:ssh_password)
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
