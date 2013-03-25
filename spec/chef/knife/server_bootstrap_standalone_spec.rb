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

require 'chef/knife/server_bootstrap_standalone'
require 'chef/knife/ssh'
require 'fakefs/spec_helpers'
require 'net/ssh'
Chef::Knife::ServerBootstrapStandalone.load_deps

describe Chef::Knife::ServerBootstrapStandalone do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBootstrapStandalone.new
    @stdout = StringIO.new
    @knife.ui.stub!(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    @knife.ui.stub!(:stderr).and_return(@stderr)
    @knife.config[:chef_node_name] = "yakky"
    @knife.config[:ssh_user] = "root"
  end

  describe "distro selection" do

    before do
      @knife.config[:bootstrap_version] = "10"
      @knife.stub(:determine_platform) { @knife.send(:distro_auto_map, "debian", "6") }
      @knife.config[:platform] = "auto"
    end

    it "should auto-select from determine_platform by default" do
      @knife.config.delete(:distro)
      @knife.send(:bootstrap_distro).should eq("chef10/debian")
      @knife.stub(:determine_platform) { "chef10/rhel" }
      @knife.send(:bootstrap_distro).should eq("chef10/rhel")
    end

    it "should construct the distro path based on the chef server version and platform" do
      @knife.send(:construct_distro, "rhel").should eq("chef10/rhel")
      @knife.config[:bootstrap_version] = "11"
      @knife.send(:construct_distro, "rhel").should eq("chef11/rhel")
    end

    it "should map the distro template based on a tuple of (platform, platform_version)" do
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
        @knife.send(:distro_auto_map, key, 0).should eq("chef10/#{value}")
        @knife.config[:bootstrap_version] = "11"
        @knife.send(:distro_auto_map, key, 0).should eq("chef11/#{value}")
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
      @knife.config[:security_groups] = %w{x y z}
      @knife.config[:tags] = %w{tag1=val1 tag2=val2}
      @knife.config[:distro] = "distro-praha"
      @knife.config[:ebs_size] = "42"
      @knife.config[:webui_password] = "daweb"
      @knife.config[:amqp_password] = "queueitup"

      ENV['_SPEC_WEBUI_PASSWORD'] = ENV['WEBUI_PASSWORD']
      ENV['_SPEC_AMQP_PASSWORD'] = ENV['AMQP_PASSWORD']
    end

    after do
      ENV['WEBUI_PASSWORD'] = ENV.delete('_SPEC_WEBUI_PASSWORD')
      ENV['AMQP_PASSWORD'] = ENV.delete('_SPEC_AMQP_PASSWORD')
    end

    let(:bootstrap) { @knife.standalone_bootstrap }

    it "returns a Bootstrap instance" do
      bootstrap.should be_a(Chef::Knife::Bootstrap)
    end

    it "copies our UI object to the bootstrap object" do
      bootstrap.ui.object_id.should eq(@knife.ui.object_id)
    end

    it "sets NO_TEST in the environment when the option is provided" do
      @knife.config[:no_test] = true
      bootstrap.should_not be_nil
      ENV["NO_TEST"].should eq("1")
      ENV.delete("NO_TEST")
    end

    it "configs the bootstrap's chef_node_name" do
      bootstrap.config[:chef_node_name].should eq("shave.yak")
    end

    it "configs the bootstrap's ssh_user" do
      bootstrap.config[:ssh_user].should eq("jdoe")
    end

    it "configs the bootstrap's ssh_password" do
      bootstrap.config[:ssh_password].should eq("nevereverguess")
    end

    it "does not config the bootstrap's ssh_password if not given" do
      @knife.config.delete(:ssh_password)

      bootstrap.config[:ssh_password].should be_nil
    end

    it "configs the bootstrap's ssh_port" do
      bootstrap.config[:ssh_port].should eq("2222")
    end

    it "configs the bootstrap's identity_file" do
      bootstrap.config[:identity_file].should eq("~/.ssh/mykey_dsa")
    end

    it "configs the bootstrap's distro" do
      bootstrap.config[:distro].should eq("distro-praha")
    end

    it "configs the bootstrap's distro to chef11/omnibus by default" do
      @knife.config.delete(:distro)

      bootstrap.config[:distro].should eq("chef11/omnibus")
    end

    it "configs the bootstrap's distro value driven off platform value" do
      @knife.config.delete(:distro)
      @knife.config[:platform] = "freebsd"

      bootstrap.config[:distro].should eq("chef11/freebsd")
    end

    it "configs the bootstrap's ENV with the webui password" do
      bootstrap
      ENV['WEBUI_PASSWORD'].should eq("daweb")
    end

    it "configs the bootstrap's ENV with the amqp password" do
      bootstrap
      ENV['AMQP_PASSWORD'].should eq("queueitup")
    end

    it "configs the bootstrap's name_args with the host" do
      bootstrap.name_args.should eq([ "172.0.10.21" ])
    end

    it "configs the bootstrap's use_sudo to true if ssh-user is not root" do
      bootstrap.config[:use_sudo].should be_true
    end

    it "configs the bootstrap's use_sudo to false if ssh-user is root" do
      @knife.config[:ssh_user] = "root"

      bootstrap.config[:use_sudo].should_not be_true
    end

    describe "#bootstrap_auto?" do
      it "should always be true if it was set via --platform, even if the distro changes" do
        @knife.config[:platform] = "auto"
        bootstrap.config[:distro].should_not eq("auto")
        @knife.send(:bootstrap_auto?).should be_true
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
      Chef::Knife::Bootstrap.stub(:new) { bootstrap }
      Knife::Server::SSH.stub(:new) { ssh }
      Knife::Server::Credentials.stub(:new) { credentials }
      credentials.stub(:install_validation_key)
      credentials.stub(:create_root_client)
    end

    after do
      [:node_name, :client_key].each do |attr|
        Chef::Config[attr] = @before_config[attr]
      end
    end

    let(:bootstrap) do
      stub(:run => true, :config => Hash.new, :ui= => true, :name_args= => true)
    end

    let(:ssh)         { stub(:exec! => true) }
    let(:credentials) { stub.as_null_object }

    it "exits if node_name option is missing" do
      @knife.config.delete(:chef_node_name)

      expect { @knife.run }.to raise_error SystemExit
    end

    it "exits if host option is missing" do
      @knife.config.delete(:host)

      expect { @knife.run }.to raise_error SystemExit
    end

    it "bootstraps a standalone server" do
      bootstrap.should_receive(:run)
      @knife.run
    end

    it "create a root client key" do
      credentials.should_receive(:create_root_client)

      @knife.run
    end

    it "installs a client key" do
      credentials.should_receive(:install_client_key).
        with("smithers", "/var/tmp/myclientkey.pem")

      @knife.run
    end

    it "installs a new validation.pem key from the chef 10 server" do
      @knife.config[:bootstrap_version] = "10"
      @knife.config[:distro] = "yabba-debian"
      Knife::Server::Credentials.should_receive(:new).
        with(ssh, "/etc/chef/validation.pem", {})
      credentials.should_receive(:install_validation_key)

      @knife.run
    end

    it "installs a new validation.pem key from the omnibus server" do
      Knife::Server::Credentials.should_receive(:new).
        with(ssh, "/etc/chef/validation.pem", {:omnibus => true})
      credentials.should_receive(:install_validation_key)

      @knife.run
    end

    context "when an ssh password is missing" do
      it "creates an SSH connection without a password" do
        Knife::Server::SSH.should_receive(:new).with({
          :host => "192.168.0.1", :port => "2345",
          :user => "root", :password => nil, :keys => []
        })

        @knife.run
      end
    end

    context "when an ssh password is provided" do
      before do
        @knife.config[:ssh_password] = "snoopy"
      end

      it "creates an SSH connection with a password" do
        Knife::Server::SSH.should_receive(:new).with({
          :host => "192.168.0.1", :port => "2345",
          :user => "root", :password => "snoopy", :keys => []
        })

        @knife.run
      end
    end

    context "when an identity file is provided" do
      before do
        @knife.config[:identity_file] = "poop.pem"
      end

      it "creates an SSH connection with an identity file" do
        Knife::Server::SSH.should_receive(:new).with({
          :host => "192.168.0.1", :port => "2345",
          :user => "root", :password => nil, :keys => ["poop.pem"]
        })

        @knife.run
      end
    end

    context "when key-based ssh authentication fails" do
      before do
        ssh.stub(:exec!).
          with("hostname -f") { raise ::Net::SSH::AuthenticationFailed }
        @knife.ui.stub(:ask)  { "hellacool" }
      end

      it "sends a authentication failure message" do
        @knife.ui.should_receive(:warn).with(/Failed to authenticate/i)

        @knife.run
      end

      it "sets the :ssh_password config from user input" do
        @knife.run

        @knife.config[:ssh_password].should eq("hellacool")
      end
    end
  end
end
