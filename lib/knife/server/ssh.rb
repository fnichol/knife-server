require 'net/ssh'

module Knife
  module Server
    class SSH
      DEFAULT_OPTIONS = { :user => "root", :port => "22" }.freeze

      def initialize(params)
        options = DEFAULT_OPTIONS.merge(params)

        @host = options.delete(:host)
        @user = options.delete(:user)
        @options = options
      end

      def exec!(cmd)
        full_cmd = (@user == "root" ? cmd : "sudo #{cmd}")
        result = ""
        Net::SSH.start(@host, @user, @options) do |ssh|
          result = ssh.exec!(full_cmd)
        end
        result
      end
    end
  end
end
