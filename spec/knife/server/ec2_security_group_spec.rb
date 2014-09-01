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

require "knife/server/ec2_security_group"

describe Knife::Server::Ec2SecurityGroup do
  let(:connection)  { double }
  let(:ui)          { double.as_null_object }
  let(:group)       { double(:name => "mygroup") }

  subject do
    Knife::Server::Ec2SecurityGroup.new(connection, ui)
  end

  def stub_groups!
    connection.stub(:security_groups) { [group] }
  end

  describe "#find_or_create" do
    context "when the group exists" do
      before do
        stub_groups!
      end

      it "returns the group" do
        subject.find_or_create("mygroup").should eq(group)
      end

      it "sends a message to the ui" do
        ui.should_receive(:msg).with("EC2 security group 'mygroup' exists")

        subject.find_or_create("mygroup")
      end
    end

    context "when the group does not exist" do
      before do
        connection.stub(:security_groups) { [double(:name => "nope")] }
        connection.stub(:create_security_group).with("mygroup", "the best") do
          stub_groups!
          true
        end
      end

      it "returns a new group" do
        subject.find_or_create("mygroup", :description => "the best").
          should eq(group)
      end

      it "sends a message to the ui" do
        ui.should_receive(:msg).with("Creating EC2 security group 'mygroup'")

        subject.find_or_create("mygroup", :description => "the best")
      end
    end
  end

  describe "#configure_chef_server_group" do
    context "with no permissions set" do
      before do
        stub_groups!
        group.stub(:ip_permissions) { [] }
        group.stub(:owner_id) { "123" }
        connection.stub(:authorize_security_group_ingress)
      end

      it "adds an icmp wildcard rule for the security group" do
        connection.should_receive(:authorize_security_group_ingress).with(
          "mygroup",
          "IpPermissions" => [
            { "FromPort" => -1, "ToPort" => -1, "IpProtocol" => "icmp",
              "Groups" => [{ "GroupName" => "mygroup", "UserId" => "123" }]
            }
          ]
        )

        subject.configure_chef_server_group("mygroup")
      end

      it "send a message for the icmp wildcard rule" do
        ui.should_receive(:msg).
          with("Creating inbound security group rule for icmp(-1 -> -1)")

        subject.configure_chef_server_group("mygroup")
      end

      %w[tcp udp].each do |proto|
        it "adds a #{proto} rule for the security group" do
          connection.should_receive(:authorize_security_group_ingress).with(
            "mygroup",
            "IpPermissions" => [
              { "IpProtocol" => proto,
                "FromPort" => 0, "ToPort" => 65535,
                "Groups" => [{ "GroupName" => "mygroup", "UserId" => "123" }]
              }
            ]
          )

          subject.configure_chef_server_group("mygroup")
        end

        it "send a message for the #{proto} security group rule" do
          ui.should_receive(:msg).with(
            "Creating inbound security group rule for #{proto}(0 -> 65535)")

          subject.configure_chef_server_group("mygroup")
        end
      end

      [22, 443, 444].each do |tcp_port|
        it "adds a tcp rule to port #{tcp_port} from anywhere" do
          connection.should_receive(:authorize_security_group_ingress).
            with("mygroup",
              "IpPermissions" => [
                { "IpProtocol" => "tcp",
                  "FromPort" => tcp_port, "ToPort" => tcp_port,
                  "IpRanges" => [{ "CidrIp" => "0.0.0.0/0" }]
                }
              ]
            )

          subject.configure_chef_server_group("mygroup")
        end

        it "send a message for the tcp/#{tcp_port} rule" do
          ui.should_receive(:msg).with("Creating inbound security group " \
            "rule for tcp(#{tcp_port} -> #{tcp_port})")

          subject.configure_chef_server_group("mygroup")
        end
      end
    end

    describe "with all permissions set" do
      def stub_perm!(proto, from, to)
        { "ipProtocol" => proto, "fromPort" => from, "toPort" => to }
      end

      before do
        stub_groups!
        group.stub(:ip_permissions) do
          [
            stub_perm!("icmp", -1, -1), stub_perm!("tcp", 0, 65535),
            stub_perm!("udp", 0, 65535), stub_perm!("tcp", 22, 22),
            stub_perm!("tcp", 443, 443), stub_perm!("tcp", 444, 444)
          ]
        end
        group.stub(:owner_id) { "123" }
        connection.stub(:authorize_security_group_ingress)
      end

      it "does not add permissions" do
        connection.should_not_receive(:authorize_security_group_ingress)

        subject.configure_chef_server_group("mygroup")
      end

      it "sends messages for the rules" do
        ui.should_receive(:msg).
          with("Inbound security group rule icmp(-1 -> -1) exists")
        ui.should_receive(:msg).
          with("Inbound security group rule tcp(0 -> 65535) exists")
        ui.should_receive(:msg).
          with("Inbound security group rule tcp(22 -> 22) exists")

        subject.configure_chef_server_group("mygroup")
      end
    end
  end
end
