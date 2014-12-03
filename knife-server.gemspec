# -*- encoding: utf-8 -*-
require File.expand_path("../lib/knife/server/version", __FILE__)
require "English"

Gem::Specification.new do |gem|
  gem.authors       = ["Fletcher Nichol"]
  gem.email         = ["fnichol@nichol.ca"]
  gem.summary       = "Chef Knife plugin to bootstrap Chef Servers"
  gem.description   = gem.summary
  gem.homepage      = "http://fnichol.github.com/knife-server"

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "knife-server"
  gem.require_paths = ["lib"]
  gem.version       = Knife::Server::VERSION

  gem.required_ruby_version = ">= 1.9.3"

  gem.add_dependency "fog"
  gem.add_dependency "net-ssh"
  gem.add_dependency "chef",      ">= 0.10.10"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "knife-digital_ocean", ">= 2.0.0"
  gem.add_development_dependency "knife-ec2", ">= 0.5.12"
  gem.add_development_dependency "knife-linode"
  gem.add_development_dependency "knife-openstack", ">= 1.0.0"

  gem.add_development_dependency "rspec", "~> 3.0"
  gem.add_development_dependency "fakefs", "~> 0.4"
  gem.add_development_dependency "timecop", "~> 0.3"
  gem.add_development_dependency "countloc",  "~> 0.4"

  # style and complexity libraries are tightly version pinned as newer releases
  # may introduce new and undesireable style choices which would be immediately
  # enforced in CI
  gem.add_development_dependency "finstyle",  "1.3.0"
  gem.add_development_dependency "cane",      "2.6.2"
end
