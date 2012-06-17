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
          "--repository ''",
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
