require 'knife/server/ssh'

describe Knife::Server::SSH do
  let(:ssh_options) do
    { :host => "wadup.example.com", :user => "bob",
      :keys => "/tmp/whoomp.key", :port => "2222" }
  end

  let(:ssh_connection) do
    stub("SSH connection").as_null_object
  end

  subject { Knife::Server::SSH.new(ssh_options) }

  before do
    Net::SSH.stub(:start).and_yield(ssh_connection)
  end

  it "passes ssh options to ssh sessions" do
    Net::SSH.should_receive(:start).with("wadup.example.com", "bob",
      { :keys => "/tmp/whoomp.key", :port => "2222" })

    subject.exec! "wat"
  end

  it "sets default user to root" do
    ssh_options.delete(:user)
    Net::SSH.should_receive(:start).with(anything, "root", anything)

    Knife::Server::SSH.new(ssh_options).exec!("wat")
  end

  it "sets default port to 22" do
    ssh_options.delete(:port)
    Net::SSH.should_receive(:start).
      with(anything, anything, hash_including(:port => "22"))

    Knife::Server::SSH.new(ssh_options).exec!("wat")
  end

  it "adds sudo to the command if user is not root" do
    ssh_options[:user] = "root"
    ssh_connection.should_receive(:exec!).with("zappa")

    Knife::Server::SSH.new(ssh_options).exec!("zappa")
  end

  it "does not add sudo to the command if user is root" do
    ssh_connection.should_receive(:exec!).with("sudo zappa")

    Knife::Server::SSH.new(ssh_options).exec!("zappa")
  end

  it "returns the output of ssh command" do
    ssh_connection.stub(:exec!).with("sudo youdoitnow") { "okthen" }

    subject.exec!("youdoitnow").should eq("okthen")
  end
end
