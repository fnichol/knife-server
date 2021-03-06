# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Copyright:: Copyright (c) 2014 Fletcher Nichol
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

require "chef/knife/server_bootstrap_digitalocean"
require "chef/knife/ssh"
require "fakefs/spec_helpers"
require "net/ssh"
Chef::Knife::ServerBootstrapDigitalocean.load_deps

describe Chef::Knife::ServerBootstrapDigitalocean do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBootstrapDigitalocean.new
    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    allow(@knife.ui).to receive(:stderr).and_return(@stderr)
    @knife.config[:chef_node_name] = "yakky"
    @knife.config[:platform] = "omnibus"
    @knife.config[:ssh_user] = "root"
  end

  let(:connection) { double(DropletKit::Client) }

  describe "#digital_ocean_bootstrap" do

    before do
      @knife.config[:chef_node_name] = "shave.yak"
      @knife.config[:ssh_user] = "jdoe"
      @knife.config[:identity_file] = "~/.ssh/mykey_dsa"
      @knife.config[:digital_ocean_access_token] = "do123"
      @knife.config[:distro] = "distro-praha"
      @knife.config[:webui_password] = "daweb"
      @knife.config[:amqp_password] = "queueitup"

      ENV["_SPEC_WEBUI_PASSWORD"] = ENV["WEBUI_PASSWORD"]
      ENV["_SPEC_AMQP_PASSWORD"] = ENV["AMQP_PASSWORD"]
    end

    after do
      ENV["WEBUI_PASSWORD"] = ENV.delete("_SPEC_WEBUI_PASSWORD")
      ENV["AMQP_PASSWORD"] = ENV.delete("_SPEC_AMQP_PASSWORD")
    end

    let(:bootstrap) { @knife.digital_ocean_bootstrap }

    it "returns a DitialOceanDropletCreate instance" do
      expect(bootstrap).to be_a(Chef::Knife::DigitalOceanDropletCreate)
    end

    it "configs the bootstrap's server_name" do
      expect(bootstrap.config[:server_name]).to eq("shave.yak")
    end

    it "configs the bootstrap's ssh_user" do
      expect(bootstrap.config[:ssh_user]).to eq("jdoe")
    end

    it "configs the bootstrap's identity_file" do
      expect(bootstrap.config[:identity_file]).to eq("~/.ssh/mykey_dsa")
    end

    it "configs the bootstrap's digital_ocean_access_token" do
      expect(bootstrap.config[:digital_ocean_access_token]).to eq("do123")
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

    it "configs the bootstrap flag to true" do
      expect(bootstrap.config[:bootstrap]).to eq(true)
    end

    it "skips config values with nil defaults" do
      expect(bootstrap.config[:bootstrap_version]).to be_nil
    end
  end

  describe "#digital_ocean_connection" do

    before do
      @before_config = Hash.new
      @before_config[:knife] = Hash.new
      [:digital_ocean_access_token].each do |key|
        @before_config[:knife][key] = Chef::Config[:knife][key]
      end

      Chef::Config[:knife][:digital_ocean_access_token] = "api"
    end

    after do
      [:digital_ocean_access_token].each do |key|
        Chef::Config[:knife][key] = @before_config[:knife][key]
      end
    end

    it "constructs a connection" do
      expect(DropletKit::Client).to receive(:new).with(:access_token => "api")

      @knife.digital_ocean_connection
    end
  end

  describe "#server_ip_address" do

    let(:droplets_resource) { double(:all => droplets) }

    before do
      @knife.config[:chef_node_name] = "yak"
      allow(@knife).to receive(:digital_ocean_connection) { connection }
      allow(connection).to receive(:droplets) { droplets_resource }
    end

    context "when single server is found" do

      let(:server) do
        double(:name => "yak", :status => "active", :public_ip => "10.11.12.13")
      end

      let(:droplets) { [server] }

      it "returns the provisioned ip address" do
        expect(@knife.server_ip_address).to eq("10.11.12.13")
      end

      it "ignores terminated instances" do
        allow(server).to receive(:status) { "foobar" }

        expect(@knife.server_ip_address).to be_nil
      end
    end

    context "when server is not found" do

      let(:droplets) { [] }

      it "returns nil" do
        expect(@knife.server_ip_address).to be_nil
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

      @knife.config[:validation_key] = "/var/tmp/validation.pem"
      @knife.config[:identity_file] = "~/.ssh/mykey_dsa"
      @knife.config[:ssh_password] = "booboo"
      allow(@knife).to receive(:digital_ocean_connection)  { connection }
      allow(@knife).to receive(:server_ip_address)  { "11.11.11.13" }
      allow(Chef::Knife::DigitalOceanDropletCreate).to receive(:new) do
        bootstrap
      end
      allow(Knife::Server::SSH).to receive(:new) { ssh }
      allow(Knife::Server::Credentials).to receive(:new) { credentials }
      allow(credentials).to receive(:install_validation_key)
      allow(credentials).to receive(:create_root_client)
    end

    after do
      [:node_name, :client_key].each do |attr|
        Chef::Config[attr] = @before_config[attr]
      end
    end

    let(:bootstrap)   { double(:run => true, :config => Hash.new) }
    let(:ssh)         { double }
    let(:credentials) { double.as_null_object }

    it "exits if Chef::Config[:node_name] is missing" do
      Chef::Config[:node_name] = nil

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if Chef::Config[:client_key] is missing" do
      Chef::Config[:client_key] = nil

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if node_name option is missing" do
      @knife.config.delete(:chef_node_name)

      expect { @knife.run }.to raise_error(SystemExit)
    end

    it "exits if platform is set to auto" do
      @knife.config[:platform] = "auto"

      expect { @knife.run }.to raise_error(SystemExit)
    end

    it "bootstraps a digital ocean server" do
      expect(bootstrap).to receive(:run)

      @knife.run
    end

    it "installs a new validation.pem key from the chef 10 server" do
      @knife.config[:bootstrap_version] = "10"
      expect(Knife::Server::SSH).to receive(:new).with(
        :host => "11.11.11.13",
        :user => "root",
        :port => "22",
        :keys => ["~/.ssh/mykey_dsa"],
        :password => "booboo"
      )
      expect(Knife::Server::Credentials).to receive(:new).
        with(ssh, "/etc/chef/validation.pem", {})
      expect(credentials).to receive(:install_validation_key)

      @knife.run
    end

    it "installs a new validation.pem key from the omnibus server" do
      expect(Knife::Server::SSH).to receive(:new).with(
        :host => "11.11.11.13",
        :user => "root",
        :port => "22",
        :keys => ["~/.ssh/mykey_dsa"],
        :password => "booboo"
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
