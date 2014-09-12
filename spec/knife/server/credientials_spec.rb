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

require "knife/server/credentials"
require "fakefs/spec_helpers"

describe Knife::Server::Credentials do
  include FakeFS::SpecHelpers

  let(:ssh)                 { double("SSH Client") }
  let(:validation_key_path) { "/tmp/validation.pem" }
  let(:client_key_path)     { "/tmp/client.pem" }
  let(:io)                  { StringIO.new }

  let(:options) do
    { :io => io }
  end

  subject do
    Knife::Server::Credentials.new(ssh, validation_key_path, options)
  end

  let(:omnibus_subject) do
    opts = { :omnibus => true }.merge(options)
    Knife::Server::Credentials.new(ssh, validation_key_path, opts)
  end

  before do
    FileUtils.mkdir_p(File.dirname(validation_key_path))
    FileUtils.mkdir_p(File.dirname(client_key_path))
    File.new(validation_key_path, "wb")  { |f| f.write("thekey") }
    File.new(client_key_path, "wb")  { |f| f.write("clientkey") }

    ENV["_SPEC_WEBUI_PASSWORD"] = ENV["WEBUI_PASSWORD"]
  end

  after do
    ENV["WEBUI_PASSWORD"] = ENV.delete("_SPEC_WEBUI_PASSWORD")
  end

  describe "#install_validation_key" do
    before do
      allow(ssh).to receive(:exec!).
        with("cat /etc/chef/validation.pem")  { "newkey" }
      allow(ssh).to receive(:exec!).
        with("cat /etc/chef-server/chef-validator.pem")  { "omnibuskey" }
    end

    it "creates a backup of the existing validation key file" do
      original = File.open("/tmp/validation.pem", "rb") { |f| f.read }
      subject.install_validation_key("old")
      backup = File.open("/tmp/validation.old.pem", "rb") { |f| f.read }

      expect(original).to eq(backup)
    end

    it "prints a message on io object about backing up the key" do
      subject.install_validation_key("old")

      expect(io.string).to include(
        "-----> Creating backup of /tmp/validation.pem locally at " \
        "/tmp/validation.old.pem"
      )
    end

    it "skips backup file creation if validation key file does not exist" do
      FileUtils.rm_f(validation_key_path)
      subject.install_validation_key("old")

      expect(File.exist?("/tmp/validation.old.pem")).to_not be_truthy
    end

    it "copies the key back from the server into validation key file" do
      subject.install_validation_key("old")
      key_str = File.open("/tmp/validation.pem", "rb") { |f| f.read }

      expect(key_str).to eq("newkey")
    end

    it "prints a message on io object about creating key file" do
      subject.install_validation_key("old")

      expect(io.string).to include(
        "-----> Installing validation private key locally at " \
        "/tmp/validation.pem"
      )
    end

    it "copies the key back from the omnibus server into validation key file" do
      omnibus_subject.install_validation_key("old")
      key_str = File.open("/tmp/validation.pem", "rb") { |f| f.read }

      expect(key_str).to eq("omnibuskey")
    end
  end

  describe "#create_root_client" do
    it "creates an initial client key on the server" do
      expect(ssh).to receive(:exec!).with([
        "knife configure --initial --server-url http://127.0.0.1:4000",
        %{--user root --repository "" --defaults --yes}
      ].join(" "))

      subject.create_root_client
    end

    it "creates an initial user on the omnibus server" do
      ENV["WEBUI_PASSWORD"] = "doowah"
      expect(ssh).to receive(:exec!).with([
        %{echo 'doowah' |},
        "knife configure --initial --server-url http://127.0.0.1:8000",
        %{--user root --repository "" --admin-client-name chef-webui},
        "--admin-client-key /etc/chef-server/chef-webui.pem",
        "--validation-client-name chef-validator",
        "--validation-key /etc/chef-server/chef-validator.pem",
        "--defaults --yes 2>> /tmp/chef-server-install-errors.txt"
      ].join(" "))

      omnibus_subject.create_root_client
    end
  end

  describe "#install_client_key" do
    before do
      allow(ssh).to receive(:exec!)
      allow(ssh).to receive(:exec!).
        with("cat /tmp/chef-client-bob.pem") { "bobkey" }
    end

    context "with no pre-exisiting key and not omnibus" do
      before { options[:omnibus] = false }

      it "creates a user client key on the server" do
        expect(ssh).to receive(:exec!).with([
          "knife client create bob --admin",
          "--file /tmp/chef-client-bob.pem --disable-editing"
        ].join(" "))

        subject.install_client_key("bob", client_key_path)
      end

      it "skips backup file creation if client key file does not exist" do
        FileUtils.rm_f(client_key_path)
        subject.install_client_key("bob", client_key_path, "old")

        expect(File.exist?("/tmp/client.old.pem")).to_not be_truthy
      end

      it "copies the key back from the server into client key file" do
        subject.install_client_key("bob", client_key_path, "old")
        key_str = File.open("/tmp/client.pem", "rb") { |f| f.read }

        expect(key_str).to eq("bobkey")
      end

      it "prints a message on io object about creating key file" do
        subject.install_client_key("bob", client_key_path, "old")

        expect(io.string).to include(
          "-----> Installing bob private key locally at /tmp/client.pem"
        )
      end

      it "removes the user client key from the server" do
        expect(ssh).to receive(:exec!).with("rm -f /tmp/chef-client-bob.pem")

        subject.install_client_key("bob", client_key_path)
      end
    end

    context "with no pre-exisiting key and omnibus" do
      before do
        options[:omnibus] = true
        FileUtils.rm_f(client_key_path)
      end

      it "creates a user client key on the server" do
        ENV["WEBUI_PASSWORD"] = "yepyep"
        expect(ssh).to receive(:exec!).with(
          "knife user create bob --admin " \
          "--file /tmp/chef-client-bob.pem --disable-editing " \
          "--password yepyep"
        )

        subject.install_client_key("bob", client_key_path)
      end

      it "skips backup file creation if client key file does not exist" do
        subject.install_client_key("bob", client_key_path, "old")

        expect(File.exist?("/tmp/client.old.pem")).to_not be_truthy
      end

      it "copies the key back from the server into client key file" do
        subject.install_client_key("bob", client_key_path, "old")
        key_str = File.open("/tmp/client.pem", "rb") { |f| f.read }

        expect(key_str).to eq("bobkey")
      end

      it "prints a message on io object about creating key file" do
        subject.install_client_key("bob", client_key_path, "old")

        expect(io.string).to include(
          "-----> Installing bob private key locally at /tmp/client.pem"
        )
      end

      it "removes the user client key from the server" do
        expect(ssh).to receive(:exec!).with("rm -f /tmp/chef-client-bob.pem")

        subject.install_client_key("bob", client_key_path)
      end
    end

    context "with a pre-existing key but not omnibus" do
      before { options[:omnibus] = false }

      it "creates the client generating a new private key on the node" do
        expect(ssh).to receive(:exec!).with(
          "knife client create jdoe --admin " \
          "--file /tmp/chef-client-jdoe.pem --disable-editing"
        )

        subject.install_client_key("jdoe", client_key_path)
      end

      it "creates a backup of the existing client key file" do
        original = File.open("/tmp/client.pem", "rb") { |f| f.read }
        subject.install_client_key("bob", client_key_path, "old")
        backup = File.open("/tmp/client.old.pem", "rb") { |f| f.read }

        expect(original).to eq(backup)
      end

      it "prints a message on io object about backing up the key" do
        subject.install_client_key("bob", client_key_path, "old")

        expect(io.string).to include(
          "-----> Creating backup of /tmp/client.pem locally at " \
          "/tmp/client.old.pem"
        )
      end

      it "removes the user client key from the server" do
        expect(ssh).to receive(:exec!).with("rm -f /tmp/chef-client-bob.pem")

        subject.install_client_key("bob", client_key_path)
      end
    end

    context "with a pre-existing key using omnibus" do
      let(:private_key) do
        <<-RSA_KEY
-----BEGIN RSA PRIVATE KEY-----
MIIEpgIBAAKCAQEAtE1zwH+ABwvCuIzjEZg2ZD1agMJGGNX2gWlbaJ6leisi8HtL
yWFJaRd/6Bm6ICgDrEBm0oGpMLffJK2qMBcKczEirsbc/biLUJG2kwFoH/I6f5BP
BErSN6mGCbZ2bVvn4114uPFmT0rJxAMsQMGS9UE3SigMxfWlZkpZYLLutU6XUDKY
w7S4l50qlNVIHy7n1O1XEIPZDf6HVEpkL+Ym91cjhy15HiEJAmFf9w5SeDjjoM2u
1lCxfKs4yt5FVqJfgqGRA8VRp2fRmWbn+tGqwBAVDphzYNpES67NJRYLQvrBXtR0
87k4DM21di/Zq6DIKx+jOkT0etAFjklMr3w32wIDAQABAoIBAQCRql1Q8PErQBoh
5Vjx9wpCc7rxeYMOP5Z2uPqrjDheegkxRjtVR+76I40no9lWb12ARUuM2EorXPG/
  fTqYvZSoudKuZ2VU6kpLXl2laKaJ4LXYJ2tfKV+qrp/mqu4ErhKrAvIsYILqnp5h
aLrQ2lLzJ6wWkkK3kBz/hiOtVwI5oReAsllsralpkQgAOB2/dFaJP/kGZjFghQsY
vAf5jzlMldTSgp1+ztrC2RKgBGUg4B5VjuBALG1AuPmnXyzEGMGDRbRhx43qckOg
WDFt3RMmIje8Qwd91eUoBbWkOKsJ5B7BT7Dli1gVP/lxEJRC+bdWVhs1r1qL8J9H
uEOxq8XhAoGBAOntpJB1tfuyRvcQuobNXIQOnPHuyhE/MTdcMT3D6tuAxqCYr7AD
pX38+8BF/FKT3VG8H1RiBbvvK8/ZJXTMc2Kp8l6R1r1QJMxYq3BM4+V3AyimlWAx
sTkQr7z1wSx4sYZ0n+WHWeZzcHPBHHHgNyY1yKWstRnoTURmTEd38acrAoGBAMVQ
hVkgdVmpJLPNcQvFeaXT8kP2MKpG4fM6yEL0i8Bf+/t9w/dFYwvLMF0c65WpEIn6
27njQhb2RsGSyECOaWMRf+rCNoatVYJhXV/LS1aEz0IZlZAWidxErTyl6fAItJfy
xBd9SzO3PBq6KEWWxNz6r2kkl0FOM2L0KzUVgVoRAoGBAOELRe3T0Cc78xlsdoWI
uyAwDryQxMSizm47uwN4n1BcKroFKb9jQqpZ3reynHO03I3tNRaw1mNeS//BH0+m
ALtCU3C3TKcDmuMbypJW5keyns9Usw+/vobvjqFyq0xlMCPxvoHKHKqfE+fIN901
ntiblVQNOoyZ9vt+jpOSyF/RAoGBAJI/F0czLqeRHboDGLnv2TVW/abvz6w1s31z
YUF3PioNOphx5BDfpgT0ylkJeXfJApAyli+WSML6MQGCyNhIdcZPDy+yWXXC/bEQ
d4PsC2AKOhA1JEzS18WiRYDBPL6DxU8mSb9bR6UCOBNbTUQe9rUPPXpB+7YUvzOl
5GyJDwHxAoGBAKH1SPQOc5tmuFW3eC0WqAd9hdMvVpn1jHzmyBaswg7wwYY7Ova9
x4PkurwpKVt7yO0uUkSOCyd2yScGNsyL+H450TSkRNxRjTJiCSriaW5abOVeQtyS
+rGmX4enOwMKsbMPUPmTuwyE2tBleK6hoMFwMeZAeJPxjJrWttfiNfLF
-----END RSA PRIVATE KEY-----
        RSA_KEY
      end

      let(:public_key) do
        <<-RSA_KEY
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtE1zwH+ABwvCuIzjEZg2
ZD1agMJGGNX2gWlbaJ6leisi8HtLyWFJaRd/6Bm6ICgDrEBm0oGpMLffJK2qMBcK
czEirsbc/biLUJG2kwFoH/I6f5BPBErSN6mGCbZ2bVvn4114uPFmT0rJxAMsQMGS
9UE3SigMxfWlZkpZYLLutU6XUDKYw7S4l50qlNVIHy7n1O1XEIPZDf6HVEpkL+Ym
91cjhy15HiEJAmFf9w5SeDjjoM2u1lCxfKs4yt5FVqJfgqGRA8VRp2fRmWbn+tGq
wBAVDphzYNpES67NJRYLQvrBXtR087k4DM21di/Zq6DIKx+jOkT0etAFjklMr3w3
2wIDAQAB
-----END PUBLIC KEY-----
        RSA_KEY
      end

      before do
        options[:omnibus] = true
        File.open(client_key_path, "wb") { |f| f.write(private_key) }
      end

      it "prints a message on io object about uploading up the key" do
        subject.install_client_key("bob", client_key_path, "old")

        expect(io.string).to include(
          "-----> Uploading public key for pre-existing bob key"
        )
      end

      it "writes the public key on the node" do
        expect(ssh).to receive(:exec!).
          with(%{echo "#{public_key}" > /tmp/chef-client-jdoe.pem})

        subject.install_client_key("jdoe", client_key_path)
      end

      it "creates the user using the public key on the node" do
        ENV["WEBUI_PASSWORD"] = "yepyep"
        expect(ssh).to receive(:exec!).with(
          "knife user create jdoe --admin " \
          "--user-key /tmp/chef-client-jdoe.pem --disable-editing " \
          "--password yepyep"
        )

        subject.install_client_key("jdoe", client_key_path)
      end

      it "removes the user client key from the server" do
        expect(ssh).to receive(:exec!).with("rm -f /tmp/chef-client-bob.pem")

        subject.install_client_key("bob", client_key_path)
      end
    end
  end
end
