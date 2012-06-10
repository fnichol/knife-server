require 'chef/knife/server_bootstrap_ec2'
require 'chef/knife/ec2_server_create'

describe Chef::Knife::ServerBootstrapEc2 do
  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBootstrapEc2.new
    @stdout = StringIO.new
    @knife.ui.stub!(:stdout).and_return(@stdout)
    @stderr = StringIO.new
    @knife.ui.stub!(:stderr).and_return(@stderr)
    @knife.config[:chef_node_name] = "yakky"
  end

  describe "#ec2_bootstrap" do
    before do
      @knife.config[:chef_node_name] = "shave.yak"
      @knife.config[:ssh_user] = "jdoe"
      @knife.config[:ssh_port] = "2222"
      @knife.config[:identity_file] = "~/.ssh/mykey_dsa"
      @knife.config[:security_groups] = %w{x y z}
      @knife.config[:tags] = %w{tag1=val1 tag2=val2}
      @knife.config[:distro] = "distro-praha"
      @knife.config[:ebs_size] = "42"
    end

    let(:bootstrap) { @knife.ec2_bootstrap }

    it "returns an Ec2ServerCreate instance" do
      bootstrap.should be_a(Chef::Knife::Ec2ServerCreate)
    end

    it "configs the bootstrap's chef_node_name" do
      bootstrap.config[:chef_node_name].should eq("shave.yak")
    end

    it "configs the bootstrap's ssh_user" do
      bootstrap.config[:ssh_user].should eq("jdoe")
    end

    it "configs the bootstrap's ssh_port" do
      bootstrap.config[:ssh_port].should eq("2222")
    end

    it "configs the bootstrap's identity_file" do
      bootstrap.config[:identity_file].should eq("~/.ssh/mykey_dsa")
    end

    it "configs the bootstrap's security_groups" do
      bootstrap.config[:security_groups].should eq(["x", "y", "z"])
    end

    it "configs the bootstrap's ebs_size" do
      bootstrap.config[:ebs_size].should eq("42")
    end

    it "configs the bootstrap's tags" do
      bootstrap.config[:tags].should include("tag1=val1")
      bootstrap.config[:tags].should include("tag2=val2")
    end

    it "adds Role=chef_server to the bootstrap's tags" do
      bootstrap.config[:tags].should include("Role=chef_server")
    end

    it "configs the bootstrap's distro" do
      bootstrap.config[:distro].should eq("distro-praha")
    end

    it "configs the bootstrap's distro to chef-server-debian by default" do
      @knife.config.delete(:distro)

      bootstrap.config[:distro].should eq("chef-server-debian")
    end

    it "configs the bootstrap's distro value driven off platform value" do
      @knife.config.delete(:distro)
      @knife.config[:platform] = "freebsd"

      bootstrap.config[:distro].should eq("chef-server-freebsd")
    end
  end

  describe "#run" do
    before do
      Chef::Knife::Ec2ServerCreate.stub(:new) { bootstrap }
    end

    let(:bootstrap) { stub(:run => true, :config => Hash.new) }

    it "exits if node_name option is missing" do
      def @knife.exit(code) ; end
      @knife.config.delete(:chef_node_name)

      @knife.should_receive(:exit)
      @knife.run
    end

    it "bootstraps an ec2 server" do
      bootstrap.should_receive(:run)
      @knife.run
    end
  end
end
