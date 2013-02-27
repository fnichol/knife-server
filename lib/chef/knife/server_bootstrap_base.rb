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

          option :platform,
            :short => "-P PLATFORM",
            :long => "--platform PLATFORM",
            :description => "The platform type that will be bootstrapped (omnibus)",
            :default => "omnibus"

          option :distro,
            :short => "-d DISTRO",
            :long => "--distro DISTRO",
            :description => "Bootstrap a distro using a template; default is 'chef11/omnibus'"

          option :bootstrap_version,
            :long => "--bootstrap-version VERSION",
            :description => "The version of Chef Server to install, default is latest release",
            :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v },
            :default => nil

          option :prerelease,
            :long => "--prerelease",
            :description => "Install a pre-release version of Chef Server"

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

      def bootstrap_auto?
        config_val(:platform) == "auto"
      end

      def distro_auto_map(platform, platform_version)
        # NOTE this logic is shared with chef/knife/bootstrap/auto.sh, which is
        #      run on the server side.
        # XXX we don't actually use the platform_version stuff, just included
        #     because we get it for free in the script and it might prove
        #     useful later.
        # XXX might be better to have chef/ohai's platform_family? do this for
        #     us in the long term.

        normal = case platform
                 when "debian", "ubuntu"
                   "debian"
                 when "el", "redhat"
                   "rhel"
                 when /^solaris/
                   "solaris"
                 when "sles", "suse"
                   "suse"
                 end

        return construct_distro(normal)
      end

      def construct_distro(platform)
        "chef#{chef_server_major_version}/#{platform}"
      end

      def chef_server_major_version
        version = config_val(:bootstrap_version)

        version.nil? ? 11 : version.split(".").first.to_i
      end

      def bootstrap_distro
        return config_val(:distro) if config_val(:distro)
        return determine_platform if config_val(:platform) == "auto"
        return construct_distro(config_val(:platform))
      end

      def credentials_client
        opts = {}
        opts[:omnibus] = true if chef_server_major_version > 10
        @credentials_client ||= ::Knife::Server::Credentials.new(
          ssh_connection, Chef::Config[:validation_key], opts)
      end

      def determine_platform
        return nil unless bootstrap_auto?

        script = File.binread(File.expand_path("bootstrap/auto.sh", File.dirname(__FILE__)))

        # result is expected to be two lines, first being the platform name,
        # second being the platform version.
        result, exit_status = ssh_connection.run_script(script)

        if exit_status != 0 or !result or result.strip.empty?
          raise "Could not determine the OS running the target for the chef server. Please specify --platform."
        end

        return distro_auto_map(*result.split(/\n/).compact[0..1])
      end

      def config_val(key)
        key = key.to_sym
        default_value = options[key] && options[key][:default]
        config.fetch(key, Chef::Config[:knife].fetch(key, default_value))
      end
    end
  end
end
