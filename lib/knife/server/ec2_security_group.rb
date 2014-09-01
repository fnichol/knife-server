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

module Knife
  module Server
    # Sets up EC2 security groups for a Chef Server.
    class Ec2SecurityGroup
      def initialize(connection, ui)
        @aws  = connection
        @ui   = ui
      end

      def configure_chef_server_group(group_name, options = {})
        group = find_or_create(group_name, options)

        ip_permissions.each do |p|
          if permission_exists?(group, p)
            @ui.msg "Inbound security group rule " \
              "#{p[:proto]}(#{p[:from]} -> #{p[:to]}) exists"
          else
            @ui.msg "Creating inbound security group rule for " \
              "#{p[:proto]}(#{p[:from]} -> #{p[:to]})"
            options = permission_options(group, p)
            @aws.authorize_security_group_ingress(group.name, options)
          end
        end
      end

      def find_or_create(name, options = {})
        group = @aws.security_groups.find { |g| g.name == name }

        if group.nil?
          @ui.msg "Creating EC2 security group '#{name}'"
          @aws.create_security_group(name, options[:description])
          group = @aws.security_groups.find { |g| g.name == name }
        else
          @ui.msg "EC2 security group '#{name}' exists"
        end

        group
      end

      private

      def ip_permissions
        [
          { :proto => "icmp", :from => -1,  :to => -1 },
          { :proto => "tcp",  :from => 0,   :to => 65535 },
          { :proto => "udp",  :from => 0,   :to => 65535 },
          { :proto => "tcp",  :from => 22,  :to => 22,  :cidr => "0.0.0.0/0" },
          { :proto => "tcp",  :from => 443, :to => 443, :cidr => "0.0.0.0/0" },
          { :proto => "tcp",  :from => 444, :to => 444, :cidr => "0.0.0.0/0" }
        ].freeze
      end

      def permission_exists?(group, perm)
        group.ip_permissions.find do |p|
          p["ipProtocol"] == perm[:proto] &&
            p["fromPort"] == perm[:from] &&
            p["toPort"]   == perm[:to]
        end
      end

      def permission_options(group, opts) # rubocop:disable Metrics/MethodLength
        options = {
          "IpPermissions" => [
            {
              "IpProtocol"  => opts[:proto],
              "FromPort"    => opts[:from],
              "ToPort"      => opts[:to]
            }
          ]
        }

        if opts[:cidr]
          options["IpPermissions"].first["IpRanges"] = [
            {
              "CidrIp" => opts[:cidr]
            }
          ]
        else
          options["IpPermissions"].first["Groups"] = [
            {
              "GroupName" => group.name,
              "UserId"    => group.owner_id
            }
          ]
        end

        options
      end
    end
  end
end
