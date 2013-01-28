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
    module ServerBootstrapBase

      def self.included(included_class)
        included_class.class_eval do

          deps do
            require 'chef/knife/ssh'
            require 'net/ssh'
          end

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
        end
      end

      private

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

      def bootstrap_distro
        config[:distro] || "chef-server-#{config[:platform]}"
      end

      def credentials_client
        opts = {}
        opts[:omnibus] = true if bootstrap_distro =~ /^omnibus-/
        @credentials_client ||= ::Knife::Server::Credentials.new(
          ssh_connection, Chef::Config[:validation_key], opts)
      end
    end
  end
end
