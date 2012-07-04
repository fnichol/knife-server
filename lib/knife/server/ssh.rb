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

require 'net/ssh'

module Knife
  module Server
    class SSH
      DEFAULT_OPTIONS = { :username => "root", :port => "22" }.freeze

      def initialize(params)
        options = DEFAULT_OPTIONS.merge(params)

        @host = options.delete(:host)
        @options = options
      end

      def exec!(cmd)
        if @options[:username] == "root"
          full_cmd = cmd
        else
          full_cmd = [
            %[sudo USER=root HOME="$(getent passwd root | cut -d : -f 6)"],
            %[bash -c '#{cmd}']
          ].join(" ")
        end

        result = ""
        Net::SSH.start(@host, @options) do |ssh|
          result = ssh.exec!(full_cmd)
        end
        result
      end
    end
  end
end
