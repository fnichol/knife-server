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

require "chef/knife/server_bootstrap_standalone"
require "chef/knife/ssh"
require "fakefs/spec_helpers"
require "net/ssh"
Chef::Knife::ServerBootstrapStandalone.load_deps

describe Chef::Knife::ServerBootstrapStandalone do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBootstrapStandalone.new
    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    allow(@knife.ui).to receive(:stderr).and_return(@stderr)
    @knife.config[:chef_node_name] = "yakky"
    @knife.config[:ssh_user] = "root"
  end

  describe "distro selection" do

    before do
      @knife.config[:bootstrap_version] = "10"
      allow(@knife).to receive(:determine_platform) do
        @knife.send(:distro_auto_map, "debian", "6")
      end
      @knife.config[:platform] = "auto"
    end

    it "should auto-select from determine_platform by default" do
      @knife.config.delete(:distro)
      expect(@knife.send(:bootstrap_distro)).to eq("chef10/debian")
      allow(@knife).to receive(:determine_platform) { "chef10/rhel" }
      expect(@knife.send(:bootstrap_distro)).to eq("chef10/rhel")
    end

    it "constructs the distro path based on chef server version and platform" do
      expect(@knife.send(:construct_distro, "rhel")).to eq("chef10/rhel")
      @knife.config[:bootstrap_version] = "11"
      expect(@knife.send(:construct_distro, "rhel")).to eq("chef11/rhel")
    end

    it "maps the distro template based on a platform/platform_version tuple" do
      {
        "el" => "rhel",
        "redhat" => "rhel",
        "debian" => "debian",
        "ubuntu" => "debian",
        "solaris2" => "solaris",
        "solaris" => "solaris",
        "sles" => "suse",
        "suse" => "suse"
      }.each do |key, value|
        @knife.config[:bootstrap_version] = "10"
        expect(@knife.send(:distro_auto_map, key, 0)).to eq("chef10/#{value}")
        @knife.config[:bootstrap_version] = "11"
        expect(@knife.send(:distro_auto_map, key, 0)).to eq("chef11/#{value}")
      end
    end
  end

  describe "#standalone_bootstrap" do

    before do
      @knife.config[:host] = "172.0.10.21"
      @knife.config[:chef_node_name] = "shave.yak"
      @knife.config[:ssh_user] = "jdoe"
      @knife.config[:ssh_password] = "nevereverguess"
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

    let(:bootstrap) { @knife.standalone_bootstrap }

    it "returns a Bootstrap instance" do
      expect(bootstrap).to be_a(Chef::Knife::Bootstrap)
    end

    it "copies our UI object to the bootstrap object" do
      expect(bootstrap.ui.object_id).to eq(@knife.ui.object_id)
    end

    it "sets NO_TEST in the environment when the option is provided" do
      @knife.config[:no_test] = true

      expect(bootstrap).to_not be_nil
      expect(ENV["NO_TEST"]).to eq("1")

      ENV.delete("NO_TEST")
    end

    it "configs the bootstrap's chef_node_name" do
      expect(bootstrap.config[:chef_node_name]).to eq("shave.yak")
    end

    it "configs the bootstrap's ssh_user" do
      expect(bootstrap.config[:ssh_user]).to eq("jdoe")
    end

    it "configs the bootstrap's ssh_password" do
      expect(bootstrap.config[:ssh_password]).to eq("nevereverguess")
    end

    it "does not config the bootstrap's ssh_password if not given" do
      @knife.config.delete(:ssh_password)

      expect(bootstrap.config[:ssh_password]).to be_nil
    end

    it "configs the bootstrap's ssh_port" do
      expect(bootstrap.config[:ssh_port]).to eq("2222")
    end

    it "configs the bootstrap's identity_file" do
      expect(bootstrap.config[:identity_file]).to eq("~/.ssh/mykey_dsa")
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

    it "configs the bootstrap's ENV with the webui password" do
      bootstrap

      expect(ENV["WEBUI_PASSWORD"]).to eq("daweb")
    end

    it "configs the bootstrap's ENV with the amqp password" do
      bootstrap

      expect(ENV["AMQP_PASSWORD"]).to eq("queueitup")
    end

    it "configs the bootstrap's name_args with the host" do
      expect(bootstrap.name_args).to eq(%w[172.0.10.21])
    end

    it "configs the bootstrap's use_sudo to true if ssh-user is not root" do
      expect(bootstrap.config[:use_sudo]).to be_truthy
    end

    it "configs the bootstrap's use_sudo to false if ssh-user is root" do
      @knife.config[:ssh_user] = "root"

      expect(bootstrap.config[:use_sudo]).to_not be_truthy
    end

    describe "#bootstrap_auto?" do
      it "should be true if set via --platform, even if the distro changes" do
        @knife.config[:platform] = "auto"
        expect(bootstrap.config[:distro]).to_not eq("auto")
        expect(@knife.send(:bootstrap_auto?)).to be_truthy
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

      @knife.config[:host] = "192.168.0.1"
      @knife.config[:ssh_port] = "2345"
      allow(Chef::Knife::Bootstrap).to receive(:new) { bootstrap }
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

    let(:bootstrap) do
      double(
        :run => true,
        :config => Hash.new,
        :ui= => true,
        :name_args= => true
      )
    end

    let(:ssh)         { double(:exec! => true) }
    let(:credentials) { double.as_null_object }

    it "exits if node_name option is missing" do
      @knife.config.delete(:chef_node_name)

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if host option is missing" do
      @knife.config.delete(:host)

      expect { @knife.run }.to raise_error SystemExit
    end

    it "bootstraps a standalone server" do
      expect(bootstrap).to receive(:run)

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

    it "installs a new validation.pem key from the chef 10 server" do
      @knife.config[:bootstrap_version] = "10"
      @knife.config[:distro] = "yabba-debian"
      expect(Knife::Server::Credentials).to receive(:new).
        with(ssh, "/etc/chef/validation.pem", {})
      expect(credentials).to receive(:install_validation_key)

      @knife.run
    end

    it "installs a new validation.pem key from the omnibus server" do
      expect(Knife::Server::Credentials).to receive(:new).
        with(ssh, "/etc/chef/validation.pem", :omnibus => true)
      expect(credentials).to receive(:install_validation_key)

      @knife.run
    end

    context "when an ssh password is missing" do
      it "creates an SSH connection without a password" do
        expect(Knife::Server::SSH).to receive(:new).with(
          :host => "192.168.0.1",
          :port => "2345",
          :user => "root",
          :password => nil,
          :keys => []
        )

        @knife.run
      end
    end

    context "when an ssh password is provided" do
      before do
        @knife.config[:ssh_password] = "snoopy"
      end

      it "creates an SSH connection with a password" do
        expect(Knife::Server::SSH).to receive(:new).with(
          :host => "192.168.0.1",
          :port => "2345",
          :user => "root",
          :password => "snoopy",
          :keys => []
        )

        @knife.run
      end
    end

    context "when an identity file is provided" do
      before do
        @knife.config[:identity_file] = "poop.pem"
      end

      it "creates an SSH connection with an identity file" do
        expect(Knife::Server::SSH).to receive(:new).with(
          :host => "192.168.0.1",
          :port => "2345",
          :user => "root",
          :password => nil,
          :keys => ["poop.pem"]
        )

        @knife.run
      end
    end

    context "when key-based ssh authentication fails" do
      before do
        allow(ssh).to receive(:exec!).
          with("hostname -f") { raise ::Net::SSH::AuthenticationFailed }
        allow(@knife.ui).to receive(:ask)  { "hellacool" }
      end

      it "sends a authentication failure message" do
        expect(@knife.ui).to receive(:warn).with(/Failed to authenticate/i)

        @knife.run
      end

      it "sets the :ssh_password config from user input" do
        @knife.run

        expect(@knife.config[:ssh_password]).to eq("hellacool")
      end
    end
  end
end
