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

require "chef/knife/server_backup"
require "fakefs/spec_helpers"
require "timecop"

describe Chef::Knife::ServerBackup do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerBackup.new
    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
    allow(@knife.ui).to receive(:msg)
    @stderr = StringIO.new
    allow(@knife.ui).to receive(:stderr).and_return(@stderr)
    @knife.config[:backup_dir] = "/baks"

    Chef::Config[:chef_server_url] = "https://chef.example.com:9876"
  end

  describe "configuration" do
    before do
      Chef::Config[:_spec_file_backup_path] = Chef::Config[:file_backup_path]
    end

    after do
      Chef::Config[:file_backup_path] = Chef::Config[:_spec_file_backup_path]
    end

    it "defaults the backup dir to <backup_dir>/<server_name>_<time>" do
      Timecop.freeze(Time.utc(2012, 1, 2, 3, 4, 5)) do
        @knife.config[:backup_dir] = nil
        Chef::Config[:file_backup_path] = "/da/bomb"

        expect(@knife.backup_dir).to eq(
          "/da/bomb/chef.example.com_20120102T030405-0000")
      end
    end
  end

  describe "#run" do
    let(:node_list) { Hash["mynode" => "http://pancakes/nodes/mynode"] }
    let(:role_list) { Hash["myrole" => "http://pancakes/roles/myrole"] }
    let(:env_list) { Hash["myenv" => "http://pancakes/envs/myenv"] }
    let(:data_bag_list) { Hash["mybag" => "http://pancakes/bags/mybag"] }
    let(:data_bag_item_list) { Hash["myitem" => "http://p/bags/mybag/myitem"] }

    before do
      allow(Chef::Node).to receive(:list) { node_list }
      allow(Chef::Node).to receive(:load).with("mynode") { stub_node("mynode") }
      allow(Chef::Role).to receive(:list) { role_list }
      allow(Chef::Role).to receive(:load).with("myrole") { stub_role("myrole") }
      allow(Chef::Environment).to receive(:list) { env_list }
      allow(Chef::Environment).to receive(:load).
        with("myenv") { stub_env("myenv") }
      allow(Chef::DataBag).to receive(:list) { data_bag_list }
      allow(Chef::DataBag).to receive(:load).
        with("mybag") { data_bag_item_list }
      allow(Chef::DataBagItem).to receive(:load).
        with("mybag", "myitem") { stub_bag_item("mybag", "myitem") }
    end

    it "exits if component type is invalid" do
      @knife.name_args = %w[nodes toasterovens]

      expect { @knife.run }.to raise_error SystemExit
    end

    context "for nodes" do
      before { @knife.name_args = %w[nodes] }

      it "creates the backup nodes dir" do
        @knife.run

        expect(File.directory?(["/baks", "nodes"].join("/"))).to be_truthy
      end

      it "sends a message to the ui" do
        expect(@knife.ui).to receive(:msg).with(/mynode/)

        @knife.run
      end

      it "writes out each node to a json file" do
        @knife.run
        json_str = File.open("/baks/nodes/mynode.json", "rb") { |f| f.read }
        json = JSON.parse(json_str, :create_additions => false)

        expect(json["name"]).to eq("mynode")
      end
    end

    context "for roles" do
      before { @knife.name_args = %w[roles] }

      it "creates the backup roles dir" do
        @knife.run
        dir = File.join("/baks", "roles")

        expect(File.directory?(dir)).to be_truthy
      end

      it "sends a message to the ui" do
        expect(@knife.ui).to receive(:msg).with(/myrole/)

        @knife.run
      end

      it "writes out each role to a json file" do
        @knife.run
        json_str = File.open("/baks/roles/myrole.json", "rb") { |f| f.read }
        json = JSON.parse(json_str, :create_additions => false)

        expect(json["name"]).to eq("myrole")
      end
    end

    context "for environments" do
      before { @knife.name_args = %w[environments] }

      it "creates the backup environments dir" do
        @knife.run
        dir = File.join("/baks", "environments")

        expect(File.directory?(dir)).to be_truthy
      end

      it "sends a message to the ui" do
        expect(@knife.ui).to receive(:msg).with(/myenv/)

        @knife.run
      end

      it "writes out each environment to a json file" do
        @knife.run
        json_str = File.open("/baks/environments/myenv.json", "rb") do |f|
          f.read
        end
        json = JSON.parse(json_str, :create_additions => false)

        expect(json["name"]).to eq("myenv")
      end

      it "skips the _default environment" do
        allow(Chef::Environment).to receive(:list) do
          Hash["_default" => "http://url"]
        end
        allow(Chef::Environment).to receive(:load).with("_default") do
          stub_env("_default")
        end
        @knife.run

        expect(File.exist?("/baks/environments/_default.json")).to_not be_truthy
      end
    end

    context "for data_bags" do
      before { @knife.name_args = %w[data_bags] }

      it "creates the backup data_bags dir" do
        @knife.run
        dir = File.join("/baks", "data_bags")

        expect(File.directory?(dir)).to be_truthy
      end

      it "sends messages to the ui" do
        expect(@knife.ui).to receive(:msg).with(/myitem/)

        @knife.run
      end

      it "writes out each data bag item to a json file" do
        @knife.run
        json_str = File.open("/baks/data_bags/mybag/myitem.json", "rb") do |f|
          f.read
        end
        json = JSON.parse(json_str, :create_additions => false)

        expect(json["name"]).to eq("data_bag_item_mybag_myitem")
      end
    end

    context "for all" do
      it "writes a node file" do
        @knife.run

        expect(File.exist?("/baks/nodes/mynode.json")).to be_truthy
      end

      it "writes a role file" do
        @knife.run

        expect(File.exist?("/baks/roles/myrole.json")).to be_truthy
      end

      it "writes an environment file" do
        @knife.run

        expect(File.exist?("/baks/environments/myenv.json")).to be_truthy
      end

      it "writes a data bag item file" do
        @knife.run

        expect(File.exist?("/baks/data_bags/mybag/myitem.json")).to be_truthy
      end
    end
  end

  private

  def stub_node(name)
    n = Chef::Node.new
    n.name(name)
    n
  end

  def stub_role(name)
    r = Chef::Role.new
    r.name(name)
    r
  end

  def stub_env(name)
    e = Chef::Environment.new
    e.name(name)
    e
  end

  def stub_bag_item(bag, name)
    d = Chef::DataBagItem.new
    d.data_bag(bag)
    d.raw_data[:id] = name
    d
  end
end
