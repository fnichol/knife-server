require 'knife/server/credentials'
require 'fakefs/spec_helpers'

describe Knife::Server::Credentials do
  include FakeFS::SpecHelpers

  let(:ssh)                 { stub("SSH Client") }
  let(:validation_key_path) { "/tmp/validation.pem" }

  subject do
    Knife::Server::Credentials.new(ssh, validation_key_path)
  end

  before do
    FileUtils.mkdir_p(File.dirname(validation_key_path))
    File.new(validation_key_path, "wb")  { |f| f.write("thekey") }
    ssh.stub(:exec!).with("sudo cat /etc/chef/validation.pem")  { "newkey" }
  end

  it "creates a backup of the existing validation key file" do
    original = File.open("/tmp/validation.pem", "rb") { |f| f.read }
    subject.install_validation_key("old")
    backup = File.open("/tmp/validation.old.pem", "rb") { |f| f.read }

    original.should eq(backup)
  end

  it "skips backup file creation if validation key file does not exist" do
    FileUtils.rm_f(validation_key_path)
    subject.install_validation_key("old")

    File.exists?("/tmp/validation.old.pem").should_not be_true
  end

  it "copies the key back from the server into validation key file" do
    subject.install_validation_key("old")
    key_str = File.open("/tmp/validation.pem", "rb") { |f| f.read }

    key_str.should eq("newkey")
  end
end
