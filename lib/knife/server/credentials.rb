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
require "openssl"

module Knife
  module Server
    # Creates credentials for a Chef server.
    class Credentials
      def initialize(ssh, validation_key_path, options = {})
        @ssh = ssh
        @validation_key_path = validation_key_path
        @omnibus = options[:omnibus]
        @io = options.delete(:io) || $stdout
      end

      def install_validation_key(suffix = Time.now.to_i)
        dest = @validation_key_path
        backup = backup_file_path(@validation_key_path, suffix)

        if File.exist?(dest)
          info "Creating backup of #{dest} locally at #{backup}"
          FileUtils.cp(dest, backup)
        end

        chef10_key = "/etc/chef/validation.pem"
        omnibus_key = "/etc/chef-server/chef-validator.pem"

        info "Installing validation private key locally at #{dest}"
        File.open(dest, "wb") do |f|
          f.write(@ssh.exec!("cat #{omnibus? ? omnibus_key : chef10_key}"))
        end
      end

      def create_root_client
        @ssh.exec!(omnibus? ? client_omnibus_cmd : client_chef10_cmd)
      end

      def install_client_key(user, client_key_path, suffix = Time.now.to_i)
        if omnibus? && File.exist?(client_key_path)
          use_current_client_key(user, client_key_path)
        else
          create_new_client_key(user, client_key_path, suffix)
        end

        @ssh.exec!("rm -f /tmp/chef-client-#{user}.pem")
      end

      private

      def info(msg)
        @io.puts "-----> #{msg}"
      end

      def omnibus?
        @omnibus ? true : false
      end

      def backup_file_path(file_path, suffix)
        parts = file_path.rpartition(".")
        "#{parts[0]}.#{suffix}.#{parts[2]}"
      end

      def create_user_client(user, is_private = false)
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
          "--#{is_private ? "user-key" : "file"} /tmp/chef-client-#{user}.pem",
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

      def use_current_client_key(user, private_key)
        public_key = OpenSSL::PKey::RSA.new(
          File.open(private_key, "rb") { |file| file.read }
        ).public_key.to_s

        info "Uploading public key for pre-existing #{user} key"
        @ssh.exec!(%{echo "#{public_key}" > /tmp/chef-client-#{user}.pem})
        create_user_client(user, true)
      end

      def create_new_client_key(user, private_key, suffix)
        create_user_client(user)

        if File.exist?(private_key)
          backup = backup_file_path(private_key, suffix)
          info "Creating backup of #{private_key} locally at #{backup}"
          FileUtils.cp(private_key, backup)
        end

        info "Installing #{user} private key locally at #{private_key}"
        File.open(private_key, "wb") do |f|
          f.write(@ssh.exec!("cat /tmp/chef-client-#{user}.pem"))
        end
      end
    end
  end
end
