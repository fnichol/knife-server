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

require 'fileutils'

module Knife
  module Server
    class Credentials
      def initialize(ssh, validation_key_path)
        @ssh = ssh
        @validation_key_path = validation_key_path
      end

      def install_validation_key(suffix = Time.now.to_i)
        if File.exists?(@validation_key_path)
          FileUtils.cp(@validation_key_path,
                       backup_file_path(@validation_key_path, suffix))
        end

        File.open(@validation_key_path, "wb") do |f|
          f.write(@ssh.exec!("cat /etc/chef/validation.pem"))
        end
      end

      def create_root_client
        @ssh.exec!([
          "knife configure",
          "--initial",
          "--server-url http://127.0.0.1:4000",
          "--user root",
          '--repository ""',
          "--defaults --yes"
        ].join(" "))
      end

      def install_client_key(user, client_key_path, suffix = Time.now.to_i)
        create_user_client(user)

        if File.exists?(client_key_path)
          FileUtils.cp(client_key_path,
                       backup_file_path(client_key_path, suffix))
        end

        File.open(client_key_path, "wb") do |f|
          f.write(@ssh.exec!("cat /tmp/chef-client-#{user}.pem"))
        end

        @ssh.exec!("rm -f /tmp/chef-client-#{user}.pem")
      end

      private

      def backup_file_path(file_path, suffix)
        parts = file_path.rpartition(".")
        "#{parts[0]}.#{suffix}.#{parts[2]}"
      end

      def create_user_client(user)
        @ssh.exec!([
          "knife client create",
          user,
          "--admin --file /tmp/chef-client-#{user}.pem --disable-editing"
        ].join(" "))
      end
    end
  end
end
