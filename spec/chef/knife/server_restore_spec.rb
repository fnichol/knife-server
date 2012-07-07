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

require 'chef/knife/server_restore'
require 'fakefs/spec_helpers'
require 'fileutils'
Chef::Knife::ServerRestore.load_deps

describe Chef::Knife::ServerRestore do
  include FakeFS::SpecHelpers

  before do
    Chef::Log.logger = Logger.new(StringIO.new)
    @knife = Chef::Knife::ServerRestore.new
    @stdout = StringIO.new
    @knife.ui.stub!(:stdout).and_return(@stdout)
    @knife.ui.stub(:msg)
    @stderr = StringIO.new
    @knife.ui.stub!(:stderr).and_return(@stderr)
    @knife.config[:backup_dir] = "/baks"
  end

  describe "#run" do
    let(:rest_client) { stub(:post_rest => true) }

    before do
      Chef::Node.any_instance.stub(:save) { true }
      Chef::Role.any_instance.stub(:save) { true }
      Chef::Environment.any_instance.stub(:save) { true }
      Chef::DataBagItem.any_instance.stub(:save) { true }
      @knife.stub(:rest) { rest_client }
    end

    it "exists if component type is invalid" do
      @knife.name_args = %w{nodes hovercraft}

      lambda { @knife.run }.should raise_error SystemExit
    end

    it "exists if backup_dir is missing" do
      @knife.config.delete(:backup_dir)

      lambda { @knife.run }.should raise_error SystemExit
    end

    context "for nodes" do
      before do
        @knife.name_args = %w{nodes}

        stub_json_node!("mynode")
      end

      it "sends a message to the ui" do
        @knife.ui.should_receive(:msg).with(/mynode/)

        @knife.run
      end

      it "saves the node" do
        Chef::Node.any_instance.should_receive(:save).once

        @knife.run
      end
    end

    context "for roles" do
      before do
        @knife.name_args = %w{roles}

        stub_json_role!("myrole")
      end

      it "sends a message to the ui" do
        @knife.ui.should_receive(:msg).with(/myrole/)

        @knife.run
      end

      it "saves the role" do
        Chef::Role.any_instance.should_receive(:save).once

        @knife.run
      end
    end

    context "for environments" do
      before do
        @knife.name_args = %w{environments}

        stub_json_env!("myenv")
      end

      it "sends a message to the ui" do
        @knife.ui.should_receive(:msg).with(/myenv/)

        @knife.run
      end

      it "saves the environment" do
        Chef::Environment.any_instance.should_receive(:save).once

        @knife.run
      end
    end

    context "for data_bags" do
      before do
        @knife.name_args = %w{data_bags}

        stub_json_data_bag_item!("mybag", "myitem")
      end

      it "sends a message to the ui" do
        @knife.ui.should_receive(:msg).with(/myitem/)

        @knife.run
      end

      it "creates the data bag" do
        rest_client.should_receive(:post_rest).
          with("data", { "name" => "mybag" })

        @knife.run
      end

      it "only creates the data bag once for multiple items" do
        stub_json_data_bag_item!("mybag", "anotheritem")
        rest_client.should_receive(:post_rest).
          with("data", { "name" => "mybag" }).once

        @knife.run
      end

      it "saves the data bag item" do
        Chef::DataBagItem.any_instance.should_receive(:save).once

        @knife.run
      end
    end

    context "for all" do
      before do
        stub_json_node!("nodey")
        stub_json_role!("roley")
        stub_json_env!("envey")
        stub_json_data_bag_item!("bagey", "itemey")
      end

      it "saves nodes" do
        Chef::Node.any_instance.should_receive(:save)

        @knife.run
      end

      it "saves roles" do
        Chef::Role.any_instance.should_receive(:save)

        @knife.run
      end

      it "saves environments" do
        Chef::Environment.any_instance.should_receive(:save)

        @knife.run
      end

      it "creates data bags" do
        rest_client.should_receive(:post_rest).
          with("data", { "name" => "bagey" })

        @knife.run
      end

      it "saves data bag items" do
        Chef::DataBagItem.any_instance.should_receive(:save)

        @knife.run
      end
    end
  end

  private

  def stub_json_node!(name)
    stub_json_component!(Chef::Node, "nodes", name)
  end

  def stub_json_role!(name)
    stub_json_component!(Chef::Role, "roles", name)
  end

  def stub_json_env!(name)
    stub_json_component!(Chef::Environment, "environments", name)
  end

  def stub_json_data_bag_item!(bag, name)
    dir = File.join(@knife.config[:backup_dir], "data_bags", bag)
    obj = Chef::DataBagItem.new
    obj.data_bag(bag)
    obj.raw_data[:id] = name
    serialize_component(obj, File.join(dir, "#{name}.json"))
  end

  def stub_json_component!(klass, plural, name)
    dir = File.join(@knife.config[:backup_dir], plural)
    obj = klass.new
    obj.name(name)
    serialize_component(obj, File.join(dir, "#{name}.json"))
  end

  def serialize_component(obj, file_path)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.open(file_path, "wb") { |f| f.write(obj.to_json) }
  end
end
