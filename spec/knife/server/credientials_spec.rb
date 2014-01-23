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

require 'knife/server/credentials'
require 'fakefs/spec_helpers'

describe Knife::Server::Credentials do
  include FakeFS::SpecHelpers

  let(:ssh)                 { double("SSH Client") }
  let(:validation_key_path) { "/tmp/validation.pem" }
  let(:client_key_path)     { "/tmp/client.pem" }

  subject do
    Knife::Server::Credentials.new(ssh, validation_key_path)
  end

  let(:omnibus_subject) do
    Knife::Server::Credentials.new(ssh, validation_key_path, :omnibus => true)
  end

  before do
    FileUtils.mkdir_p(File.dirname(validation_key_path))
    FileUtils.mkdir_p(File.dirname(client_key_path))
    File.new(validation_key_path, "wb")  { |f| f.write("thekey") }
    File.new(client_key_path, "wb")  { |f| f.write("clientkey") }

    ENV['_SPEC_WEBUI_PASSWORD'] = ENV['WEBUI_PASSWORD']
  end

  after do
    ENV['WEBUI_PASSWORD'] = ENV.delete('_SPEC_WEBUI_PASSWORD')
  end

  describe "#install_validation_key" do
    before do
      ssh.stub(:exec!).with("cat /etc/chef/validation.pem")  { "newkey" }
      ssh.stub(:exec!).
        with("cat /etc/chef-server/chef-validator.pem")  { "omnibuskey" }
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

    it "copies the key back from the omnibus server into validation key file" do
      omnibus_subject.install_validation_key("old")
      key_str = File.open("/tmp/validation.pem", "rb") { |f| f.read }

      key_str.should eq("omnibuskey")
    end
  end

  describe "#create_root_client" do
    it "creates an initial client key on the server" do
      ssh.should_receive(:exec!).with([
        'knife configure --initial --server-url http://127.0.0.1:4000',
        '--user root --repository "" --defaults --yes'
      ].join(" "))

      subject.create_root_client
    end

    it "creates an initial user on the omnibus server" do
      ENV['WEBUI_PASSWORD'] = 'doowah'
      ssh.should_receive(:exec!).with([
        "echo 'doowah' |",
        'knife configure --initial --server-url http://127.0.0.1:8000',
        '--user root --repository "" --admin-client-name chef-webui',
        '--admin-client-key /etc/chef-server/chef-webui.pem',
        '--validation-client-name chef-validator',
        '--validation-key /etc/chef-server/chef-validator.pem',
        '--defaults --yes'
      ].join(" "))

      omnibus_subject.create_root_client
    end
  end

  describe "#install_client_key" do
    before do
      ssh.stub(:exec!)
      ssh.stub(:exec!).with("cat /tmp/chef-client-bob.pem") { "bobkey" }
    end

    it "creates a user client key on the server" do
      ssh.should_receive(:exec!).with([
        "knife client create bob --admin",
        "--file /tmp/chef-client-bob.pem --disable-editing",
      ].join(" "))

      subject.install_client_key("bob", client_key_path)
    end

    it "creates a backup of the existing client key file" do
      original = File.open("/tmp/client.pem", "rb") { |f| f.read }
      subject.install_client_key("bob", client_key_path, "old")
      backup = File.open("/tmp/client.old.pem", "rb") { |f| f.read }

      original.should eq(backup)
    end

    it "skips backup file creation if client key file does not exist" do
      FileUtils.rm_f(client_key_path)
      subject.install_client_key("bob", client_key_path, "old")

      File.exists?("/tmp/client.old.pem").should_not be_true
    end

    it "copies the key back from the server into client key file" do
      subject.install_client_key("bob", client_key_path, "old")
      key_str = File.open("/tmp/client.pem", "rb") { |f| f.read }

      key_str.should eq("bobkey")
    end

    it "removes the user client key from the server" do
      ssh.should_receive(:exec!).with("rm -f /tmp/chef-client-bob.pem")

      subject.install_client_key("bob", client_key_path)
    end
  end
end
