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

require "chef/knife"
require "chef/node"

class Chef
  class Knife
    # Backs up a Chef server component.
    class ServerBackup < Knife

      deps do
        require "fileutils"
        require "uri"
      end

      banner "knife server backup COMPONENT[ COMPONENT ...] (options)"

      option :backup_dir,
        :short => "-D DIR",
        :long => "--backup-dir DIR",
        :description => "The directory to host backup files"

      option :pretty_print,
        :short => "-P",
        :long => "--pretty_print",
        :description => "Generate Pretty JSON for file."

      def run
        validate!
        components = name_args.empty? ? COMPONENTS.keys : name_args

        Array(components).each { |component| backup_component(component) }
      end

      def backup_dir
        @backup_dir ||= config[:backup_dir] || begin
          server_host = URI.parse(Chef::Config[:chef_server_url]).host
          time = Time.now.utc.strftime("%Y%m%dT%H%M%S-0000")
          base_dir = config[:backup_dir] || Chef::Config[:file_backup_path]

          ::File.join(base_dir, "#{server_host}_#{time}")
        end
      end

      private

      COMPONENTS = {
        "nodes" => {
          :singular => "node",
          :klass => Chef::Node
        },
        "roles" => {
          :singular => "role",
          :klass => Chef::Role
        },
        "environments" => {
          :singular => "environment",
          :klass => Chef::Environment
        },
        "data_bags" => {
          :singular => "data_bag",
          :klass => Chef::DataBag
        }
      }

      def validate!
        bad_names = name_args.reject { |c| COMPONENTS.keys.include?(c) }
        unless bad_names.empty?
          ui.error "Component types #{bad_names.inspect} are not valid."
          exit 1
        end
      end

      def backup_component(component)
        c = COMPONENTS[component]
        dir_path = ::File.join(backup_dir, component)
        ui.msg "Creating #{c[:singular]} backups in #{dir_path}"
        FileUtils.mkdir_p(dir_path)

        Array(c[:klass].list).each do |name, _url|
          next if component == "environments" && name == "_default"

          case component
          when "data_bags"
            write_data_bag_items(name, dir_path, c)
          else
            write_component(name, dir_path, c)
          end
        end
      end

      def write_component(name, dir_path, c)
        obj = c[:klass].load(name)
        ui.msg "Backing up #{c[:singular]}[#{name}]"
        ::File.open(::File.join(dir_path, "#{name}.json"), "wb") do |f|
          if config[:pretty_print]
            f.write(JSON.pretty_generate(obj))
          else
            f.write(obj.to_json)
          end
        end
      end

      def write_data_bag_items(name, dir_path, c)
        item_path = ::File.join(dir_path, name)
        FileUtils.mkdir_p(item_path)

        Array(c[:klass].load(name)).each do |item_name, _url|
          obj = Chef::DataBagItem.load(name, item_name)
          ui.msg "Backing up #{c[:singular]}[#{name}][#{item_name}]"
          ::File.open(::File.join(item_path, "#{item_name}.json"), "wb") do |f|
            if config[:pretty_print]
              f.write(JSON.pretty_generate(obj))
            else
              f.write(obj.to_json)
            end
          end
        end
      end
    end
  end
end
