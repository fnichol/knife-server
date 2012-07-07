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

require 'chef/knife'

class Chef
  class Knife
    class ServerRestore < Knife

      deps do
        require 'chef/json_compat'
      end

      banner "knife server restore COMPONENT[ COMPONENT ...] (options)"

      option :backup_dir,
        :short => "-D DIR",
        :long => "--backup-dir DIR",
        :description => "The directory containing backup files"

      def run
        validate!
        components = name_args.empty? ? COMPONENTS.keys : name_args

        Array(components).each { |type| restore_components(type) }
      end

      private

      COMPONENTS = {
        "nodes" => { :singular => "node", :klass => Chef::Node },
        "roles" => { :singular => "role", :klass => Chef::Role },
        "environments" => { :singular => "environment", :klass => Chef::Environment },
        "data_bags" => { :singular => "data_bag", :klass => Chef::DataBag },
      }

      def validate!
        bad_names = name_args.reject { |c| COMPONENTS.keys.include?(c) }
        unless bad_names.empty?
          ui.error "Component types #{bad_names.inspect} are not valid."
          exit 1
        end
        if config[:backup_dir].nil?
          ui.error "You did not provide a valid --backup-dir value."
          exit 1
        end
      end

      def restore_components(type)
        c = COMPONENTS[type]
        dir_path = ::File.join(config[:backup_dir], type)

        Array(Dir.glob(::File.join(dir_path, "**/*.json"))).each do |json_file|
          restore_component(c, json_file)
        end
      end

      def restore_component(c, json_file)
        obj = Chef::JSONCompat.from_json(
          ::File.open(json_file, "rb") { |f| f.read }
        )

        if c[:klass] == Chef::DataBag
          create_data_bag(::File.basename(::File.dirname(json_file)))
          msg = "Restoring #{c[:singular]}" +
            "[#{obj.data_bag}][#{obj.raw_data[:id]}]"
        else
          msg = "Restoring #{c[:singular]}[#{obj.name}]"
        end

        ui.msg msg
        obj.save
      end

      def create_data_bag(name)
        @created_data_bags ||= []

        unless @created_data_bags.include?(name)
          ui.msg "Restoring data_bag[#{name}]"
          rest.post_rest("data", { "name" => name })
          @created_data_bags << name
        end
      end
    end
  end
end
