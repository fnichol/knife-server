# -*- encoding: utf-8 -*-
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

require "fileutils"

module Knife
  module Server
    # Creates credentials for a Chef server.
    class Credentials
      def initialize(ssh, validation_key_path, options = {})
        @ssh = ssh
        @validation_key_path = validation_key_path
        @omnibus = options[:omnibus]
      end

      def install_validation_key(suffix = Time.now.to_i)
        if File.exist?(@validation_key_path)
          FileUtils.cp(
            @validation_key_path,
            backup_file_path(@validation_key_path, suffix)
          )
        end

        chef10_key = "/etc/chef/validation.pem"
        omnibus_key = "/etc/chef-server/chef-validator.pem"

        File.open(@validation_key_path, "wb") do |f|
          f.write(@ssh.exec!("cat #{omnibus? ? omnibus_key : chef10_key}"))
        end
      end

      def create_root_client
        @ssh.exec!(omnibus? ? client_omnibus_cmd : client_chef10_cmd)
      end

      def install_client_key(user, client_key_path, suffix = Time.now.to_i)
        create_user_client(user)

        if File.exist?(client_key_path)
          FileUtils.cp(
            client_key_path,
            backup_file_path(client_key_path, suffix)
          )
        end

        File.open(client_key_path, "wb") do |f|
          f.write(@ssh.exec!("cat /tmp/chef-client-#{user}.pem"))
        end

        @ssh.exec!("rm -f /tmp/chef-client-#{user}.pem")
      end

      private

      def omnibus?
        @omnibus ? true : false
      end

      def backup_file_path(file_path, suffix)
        parts = file_path.rpartition(".")
        "#{parts[0]}.#{suffix}.#{parts[2]}"
      end

      def create_user_client(user)
        chef10_cmd = [
          "knife client create",
          user,
          "--admin",
          "--file /tmp/chef-client-#{user}.pem",
          "--disable-editing"
        ].join(" ")

        omnibus_cmd = [
          "knife user create",
          user,
          "--admin",
          "--file /tmp/chef-client-#{user}.pem",
          "--disable-editing",
          "--password #{ENV["WEBUI_PASSWORD"]}"
        ].join(" ")

        @ssh.exec!(omnibus? ? omnibus_cmd : chef10_cmd)
      end

      def client_chef10_cmd
        [
          "knife configure",
          "--initial",
          "--server-url http://127.0.0.1:4000",
          "--user root",
          '--repository ""',
          "--defaults --yes"
        ].join(" ")
      end

      def client_omnibus_cmd
        [
          "echo '#{ENV["WEBUI_PASSWORD"]}' |",
          "knife configure",
          "--initial",
          "--server-url http://127.0.0.1:8000",
          "--user root",
          '--repository ""',
          "--admin-client-name chef-webui",
          "--admin-client-key /etc/chef-server/chef-webui.pem",
          "--validation-client-name chef-validator",
          "--validation-key /etc/chef-server/chef-validator.pem",
          "--defaults --yes 2>> /tmp/chef-server-install-errors.txt"
        ].join(" ")
      end
    end
  end
end
