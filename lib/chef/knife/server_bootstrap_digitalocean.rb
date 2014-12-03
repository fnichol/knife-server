# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Copyright:: Copyright (c) 2014 Fletcher Nichol
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
    # Provisions a Digital Ocean instance and sets up an Open Source Chef
    # Server.
    class ServerBootstrapDigitalocean < Knife

      banner "knife server bootstrap digitalocean (options)"

      include Knife::ServerBootstrapBase

      deps do
        require "knife/server/ssh"
        require "knife/server/credentials"

        begin
          require "chef/knife/digital_ocean_droplet_create"
          require "droplet_kit"
          Chef::Knife::DigitalOceanDropletCreate.load_deps

          current_options = options
          self.options = Chef::Knife::DigitalOceanDropletCreate.options.dup
          options.merge!(current_options)
        rescue LoadError => ex
          ui.error [
            "Knife plugin knife-digital_ocean could not be loaded.",
            "Please add the knife-digital_ocean gem to your Gemfile or",
            "install the gem manually with `gem install knife-digital_ocean'.",
            "(#{ex.message})"
          ].join(" ")
          exit 1
        end

        # Monkey patch to prevent Kernel#exit calls at the end of the upstream
        # Knife plugin. Instead, non-zero exits will be raised and zero exits
        # will be ignored ;)
        #
        # rubocop:disable Style/ClassAndModuleChildren
        class ::Chef::Knife::DigitalOceanDropletCreate
          def exit(code)
            if code != 0
              raise "DigitalOceanDropletCreate exited with code: #{code}"
            end
          end
        end
        # rubocop:enable Style/ClassAndModuleChildren
      end

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The Chef node name for your new node",
        :proc => proc { |key| Chef::Config[:knife][:server_name] = key }

      def run
        super
        digital_ocean_bootstrap.run
        fetch_validation_key
        create_root_client
        install_client_key
      end

      def digital_ocean_bootstrap
        setup_environment
        bootstrap = Chef::Knife::DigitalOceanDropletCreate.new
        bootstrap.config[:bootstrap] = true
        Chef::Knife::DigitalOceanDropletCreate.options.keys.each do |attr|
          val = config_val(attr)
          next if val.nil?

          bootstrap.config[attr] = val
        end
        bootstrap.config[:server_name] = config_val(:chef_node_name)
        bootstrap.config[:distro] = bootstrap_distro
        bootstrap
      end

      def digital_ocean_connection
        @digital_ocean_connection ||= DropletKit::Client.new(
          :access_token => config_val(:digital_ocean_access_token)
        )
      end

      def server_ip_address
        server = digital_ocean_connection.droplets.all.find do |s|
          s.status == "active" && s.name == config_val(:chef_node_name)
        end

        server && server.public_ip
      end

      private

      def validate!
        super

        if config[:chef_node_name].nil?
          ui.error "You did not provide a valid --node-name value."
          exit 1
        end
        if config_val(:platform) == "auto"
          ui.error "Auto platform mode cannot be used with " \
            "knife-digital_ocean plugin"
          exit 1
        end
      end

      def setup_environment
        ENV["WEBUI_PASSWORD"] = config_val(:webui_password)
        ENV["AMQP_PASSWORD"] = config_val(:amqp_password)
        ENV["NO_TEST"] = "1" if config[:no_test]
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
