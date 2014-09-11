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

require "net/ssh"

module Knife
  module Server
    # Communicates with an SSH node.
    class SSH
      DEFAULT_OPTIONS = { :user => "root", :port => "22" }.freeze
      USER_SWITCH_COMMAND =
        %{sudo USER=root HOME="$(getent passwd root | cut -d : -f 6)"}.freeze

      def initialize(params)
        options = DEFAULT_OPTIONS.merge(params)

        @host = options.delete(:host)
        @user = options.delete(:user)
        @options = options
      end

      def exec!(cmd)
        result = ""
        exit_code = nil
        Net::SSH.start(@host, @user, @options) do |session|
          exit_code = ssh_session(session, full_cmd(cmd), result)
        end
        if exit_code != 0
          raise "SSH exited with code #{exit_code} for [#{full_cmd(cmd)}]"
        end
        result
      end

      def full_cmd(cmd)
        if @user == "root"
          cmd
        else
          [USER_SWITCH_COMMAND, %{bash -c '#{cmd}'}].join(" ")
        end
      end

      def ssh_session(session, cmd, result)
        exit_code = nil
        session.open_channel do |channel|

          channel.request_pty

          channel.exec(cmd) do |_ch, _success|

            channel.on_data do |_ch, data|
              result << data
            end

            channel.on_extended_data do |_ch, _type, data|
              result << data
            end

            channel.on_request("exit-status") do |_ch, data|
              exit_code = data.read_long
            end
          end
        end

        session.loop
        exit_code
      end

      # runs a script on the target host by passing it to the stdin of a sh
      # process. returns stdout and the exit status. does not care about stderr.
      def run_script(content)
        user_switch = ""

        unless @user == "root"
          user_switch = USER_SWITCH_COMMAND
        end

        wrapper = <<-EOF
        if [ -e /dev/fd/0 ]
        then
          #{user_switch} /bin/sh /dev/fd/0
        elif [ -e /dev/stdin ]
        then
          #{user_switch} /bin/sh /dev/stdin
        else
          echo "Cannot find method of communicating with the shell via stdin"
          exit 1
        fi
        EOF

        exec_ssh(wrapper, content)
      end

      def exec_ssh(wrapper, content) # rubocop:disable Metrics/MethodLength
        result = ""
        exit_status = nil

        Net::SSH.start(@host, @user, @options) do |ssh|
          ssh.open_channel do |ch|
            ch.on_open_failed do |_, _, desc|
              raise "Connection Error to #{ip}: #{desc}"
            end

            ch.exec(wrapper) do |channel, _, _|
              # spit out the shell script and close stdin so sh can do its magic
              channel.send_data(content)
              channel.eof!

              # then we just wait for sweet, sweet output
              channel.on_data do |_, data|
                result << data
              end

              channel.on_request("exit-status") do |_, data|
                exit_status = data.read_long
              end
            end

            ch.wait
          end

          ssh.loop
        end

        [result, exit_status]
      end
    end
  end
end
