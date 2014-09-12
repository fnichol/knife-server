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

require "chef/knife/server_bootstrap_ec2"
require "chef/knife/ssh"
require "fakefs/spec_helpers"
require "net/ssh"
Chef::Knife::ServerBootstrapEc2.load_deps

describe Chef::Knife::ServerBootstrapEc2 do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBootstrapEc2.new
    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    allow(@knife.ui).to receive(:stderr).and_return(@stderr)
    @knife.config[:chef_node_name] = "yakky"
    @knife.config[:platform] = "omnibus"
    @knife.config[:ssh_user] = "root"
  end

  let(:connection) { double(Fog::Compute::AWS) }

  describe "#ec2_bootstrap" do
    before do
      @knife.config[:chef_node_name] = "shave.yak"
      @knife.config[:ssh_user] = "jdoe"
      @knife.config[:ssh_port] = "2222"
      @knife.config[:identity_file] = "~/.ssh/mykey_dsa"
      @knife.config[:security_groups] = %w[x y z]
      @knife.config[:tags] = %w[tag1=val1 tag2=val2]
      @knife.config[:distro] = "distro-praha"
      @knife.config[:ebs_size] = "42"
      @knife.config[:webui_password] = "daweb"
      @knife.config[:amqp_password] = "queueitup"

      ENV["_SPEC_WEBUI_PASSWORD"] = ENV["WEBUI_PASSWORD"]
      ENV["_SPEC_AMQP_PASSWORD"] = ENV["AMQP_PASSWORD"]
    end

    after do
      ENV["WEBUI_PASSWORD"] = ENV.delete("_SPEC_WEBUI_PASSWORD")
      ENV["AMQP_PASSWORD"] = ENV.delete("_SPEC_AMQP_PASSWORD")
    end

    let(:bootstrap) { @knife.ec2_bootstrap }

    it "returns an Ec2ServerCreate instance" do
      expect(bootstrap).to be_a(Chef::Knife::Ec2ServerCreate)
    end

    it "configs the bootstrap's chef_node_name" do
      expect(bootstrap.config[:chef_node_name]).to eq("shave.yak")
    end

    it "configs the bootstrap's ssh_user" do
      expect(bootstrap.config[:ssh_user]).to eq("jdoe")
    end

    it "configs the bootstrap's ssh_port" do
      expect(bootstrap.config[:ssh_port]).to eq("2222")
    end

    it "configs the bootstrap's identity_file" do
      expect(bootstrap.config[:identity_file]).to eq("~/.ssh/mykey_dsa")
    end

    it "configs the bootstrap's security_groups" do
      expect(bootstrap.config[:security_groups]).to eq(%w[x y z])
    end

    it "configs the bootstrap's ebs_size" do
      expect(bootstrap.config[:ebs_size]).to eq("42")
    end

    it "configs the bootstrap's tags" do
      expect(bootstrap.config[:tags]).to include("tag1=val1")
      expect(bootstrap.config[:tags]).to include("tag2=val2")
    end

    it "adds Role=chef_server to the bootstrap's tags" do
      expect(bootstrap.config[:tags]).to include("Role=chef_server")
    end

    it "configs the bootstrap's distro" do
      expect(bootstrap.config[:distro]).to eq("distro-praha")
    end

    it "configs the bootstrap's distro to chef11/omnibus by default" do
      @knife.config.delete(:distro)

      expect(bootstrap.config[:distro]).to eq("chef11/omnibus")
    end

    it "configs the bootstrap's distro value driven off platform value" do
      @knife.config.delete(:distro)
      @knife.config[:platform] = "freebsd"

      expect(bootstrap.config[:distro]).to eq("chef11/freebsd")
    end

    it "configs the distro based on bootstrap_version and platform" do
      @knife.config.delete(:distro)
      @knife.config[:platform] = "freebsd"
      @knife.config[:bootstrap_version] = "10"

      expect(bootstrap.config[:distro]).to eq("chef10/freebsd")
    end

    it "configs the bootstrap's ENV with the webui password" do
      bootstrap

      expect(ENV["WEBUI_PASSWORD"]).to eq("daweb")
    end

    it "configs the bootstrap's ENV with the amqp password" do
      bootstrap

      expect(ENV["AMQP_PASSWORD"]).to eq("queueitup")
    end

    it "skips config values with nil defaults" do
      expect(bootstrap.config[:bootstrap_version]).to be_nil
    end
  end

  describe "#ec2_connection" do
    before do
      @before_config = Hash.new
      @before_config[:knife] = Hash.new
      [:aws_access_key_id, :aws_secret_access_key, :region].each do |attr|
        @before_config[:knife][attr] = Chef::Config[:knife][attr]
      end

      Chef::Config[:knife][:aws_access_key_id] = "key"
      Chef::Config[:knife][:aws_secret_access_key] = "secret"
      Chef::Config[:knife][:region] = "hell-south-666"
    end

    after do
      [:aws_access_key_id, :aws_secret_access_key, :region].each do |attr|
        Chef::Config[:knife][attr] = @before_config[:knife][attr]
      end
    end

    it "constructs a connection" do
      expect(Fog::Compute).to receive(:new).with(
        :provider => "AWS",
        :aws_access_key_id => "key",
        :aws_secret_access_key => "secret",
        :region => "hell-south-666"
      )

      @knife.ec2_connection
    end
  end

  describe "#server_dns_name" do
    before do
      @knife.config[:chef_node_name] = "shavemy.yak"
      allow(@knife).to receive(:ec2_connection) { connection }
    end

    context "when server is found" do
      before do
        expect(connection).to receive(:servers) { [server] }
      end

      let(:server) do
        double(
          :dns_name => "blahblah.aws.compute.com",
          :state => "running",
          :tags => { "Name" => "shavemy.yak", "Role" => "chef_server" }
        )
      end

      it "returns the provisioned dns name" do
        expect(@knife.server_dns_name).to eq("blahblah.aws.compute.com")
      end

      it "ignores terminated instances" do
        allow(server).to receive(:state) { "terminated" }

        expect(@knife.server_dns_name).to be_nil
      end
    end

    context "when server is not found" do
      before do
        allow(connection).to receive(:servers) { [] }
      end

      it "returns nil" do
        expect(@knife.server_dns_name).to be_nil
      end
    end
  end

  describe "#run" do
    before do
      @before_config = Hash.new
      [:node_name, :client_key].each do |attr|
        @before_config[attr] = Chef::Config[attr]
      end
      Chef::Config[:node_name] = "smithers"
      Chef::Config[:client_key] = "/var/tmp/myclientkey.pem"

      @knife.config[:security_groups] = ["mygroup"]
      @knife.config[:validation_key] = "/var/tmp/validation.pem"
      @knife.config[:ssh_port] = "2345"
      @knife.config[:identity_file] = "~/.ssh/mykey_dsa"
      allow(@knife).to receive(:ec2_connection)  { connection }
      allow(@knife).to receive(:server_dns_name)  { "grapes.wrath" }
      allow(Chef::Knife::Ec2ServerCreate).to receive(:new) { bootstrap }
      allow(Knife::Server::Ec2SecurityGroup).to receive(:new) { security_group }
      allow(Knife::Server::SSH).to receive(:new) { ssh }
      allow(Knife::Server::Credentials).to receive(:new) { credentials }
      allow(security_group).to receive(:configure_chef_server_group)
      allow(credentials).to receive(:install_validation_key)
      allow(credentials).to receive(:create_root_client)
    end

    after do
      [:node_name, :client_key].each do |attr|
        Chef::Config[attr] = @before_config[attr]
      end
    end

    let(:bootstrap)       { double(:run => true, :config => Hash.new) }
    let(:security_group)  { double }
    let(:ssh)             { double }
    let(:credentials)     { double.as_null_object }

    it "exits if Chef::Config[:node_name] is missing" do
      Chef::Config[:node_name] = nil

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if Chef::Config[:client_key] is missing" do
      Chef::Config[:client_key] = nil

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if node_name option is missing" do
      def @knife.exit(_); end
      @knife.config.delete(:chef_node_name)

      expect(@knife).to receive(:exit)
      @knife.run
    end

    it "configures the ec2 security group" do
      expect(Knife::Server::Ec2SecurityGroup).to receive(:new).
        with(connection, @knife.ui)
      expect(security_group).to receive(:configure_chef_server_group).
        with("mygroup", :description => "mygroup group")

      @knife.run
    end

    it "bootstraps an ec2 server" do
      expect(bootstrap).to receive(:run)

      @knife.run
    end

    it "installs a new validation.pem key from the chef 10 server" do
      @knife.config[:bootstrap_version] = "10"
      expect(Knife::Server::SSH).to receive(:new).with(
        :host => "grapes.wrath",
        :user => "root",
        :port => "2345",
        :keys => ["~/.ssh/mykey_dsa"]
      )
      expect(Knife::Server::Credentials).to receive(:new).
        with(ssh, "/etc/chef/validation.pem", {})
      expect(credentials).to receive(:install_validation_key)

      @knife.run
    end

    it "installs a new validation.pem key from the omnibus server" do
      expect(Knife::Server::SSH).to receive(:new).with(
        :host => "grapes.wrath",
        :user => "root",
        :port => "2345",
        :keys => ["~/.ssh/mykey_dsa"]
      )
      expect(Knife::Server::Credentials).to receive(:new).
        with(ssh, "/etc/chef/validation.pem", :omnibus => true)
      expect(credentials).to receive(:install_validation_key)

      @knife.run
    end

    it "create a root client key" do
      expect(credentials).to receive(:create_root_client)

      @knife.run
    end

    it "installs a client key" do
      expect(credentials).to receive(:install_client_key).
        with("smithers", "/var/tmp/myclientkey.pem")

      @knife.run
    end
  end
end
