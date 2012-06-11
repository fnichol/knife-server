require 'chef/knife/server_bootstrap_ec2'
require 'chef/knife/ec2_server_create'
require 'fog'

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

  let(:connection) { mock(Fog::Compute::AWS) }

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

  describe "#ec2_connection" do
    before do
      Chef::Config[:_spec_knife] = Chef::Config[:knife].dup
      Chef::Config[:knife][:aws_access_key_id] = "key"
      Chef::Config[:knife][:aws_secret_access_key] = "secret"
      Chef::Config[:knife][:region] = "hell-south-666"
    end

    after do
      Chef::Config[:knife] = Chef::Config.delete(:_spec_knife)
    end

    it "constructs a connection" do
      Fog::Compute.should_receive(:new).with({
        :provider => 'AWS',
        :aws_access_key_id => 'key',
        :aws_secret_access_key => 'secret',
        :region => 'hell-south-666'
      })

      @knife.ec2_connection
    end
  end

  describe "#server_dns_name" do
    before do
      @knife.config[:chef_node_name] = 'shavemy.yak'
      @knife.stub(:ec2_connection) { connection }
    end

    context "when server is found" do
      before do
        connection.stub(:servers) { [server] }
      end

      let(:server) do
        stub(:dns_name => 'blahblah.aws.compute.com', :state => "running",
          :tags => {'Name' => 'shavemy.yak', 'Role' => 'chef_server'})
      end

      it "returns the provisioned dns name" do
        @knife.server_dns_name.should eq('blahblah.aws.compute.com')
      end

      it "ignores terminated instances" do
        server.stub(:state) { "terminated" }
        @knife.server_dns_name.should be_nil
      end
    end

    context "when server is not found" do
      before do
        connection.stub(:servers) { [] }
      end

      it "returns nil" do
        @knife.server_dns_name.should be_nil
      end
    end
  end

  describe "#run" do
    before do
      @knife.config[:security_groups] = ["mygroup"]
      @knife.stub(:ec2_connection)  { connection }
      Chef::Knife::Ec2ServerCreate.stub(:new) { bootstrap }
      Knife::Server::Ec2SecurityGroup.stub(:new) { security_group }
      security_group.stub(:configure_chef_server_group)
    end

    let(:bootstrap)       { stub(:run => true, :config => Hash.new) }
    let(:security_group)  { stub }

    it "exits if node_name option is missing" do
      def @knife.exit(code) ; end
      @knife.config.delete(:chef_node_name)

      @knife.should_receive(:exit)
      @knife.run
    end

    it "configures the ec2 security group" do
      Knife::Server::Ec2SecurityGroup.should_receive(:new).
        with(connection, @knife.ui)
      security_group.should_receive(:configure_chef_server_group).
        with('mygroup', :description => 'mygroup group')

      @knife.run
    end

    it "bootstraps an ec2 server" do
      bootstrap.should_receive(:run)
      @knife.run
    end
  end
end
