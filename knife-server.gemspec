# -*- encoding: utf-8 -*-
require File.expand_path('../lib/knife/server/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Fletcher Nichol"]
  gem.email         = ["fnichol@nichol.ca"]
  gem.summary       = %q{Chef Knife plugin to bootstrap Chef Servers}
  gem.description   = gem.summary
  gem.homepage      = "http://fnichol.github.com/knife-server"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "knife-server"
  gem.require_paths = ["lib"]
  gem.version       = Knife::Server::VERSION

  gem.add_dependency "fog",       "~> 1.3"
  gem.add_dependency "net-ssh"
  gem.add_dependency "chef",      ">= 0.10.10"
  gem.add_dependency "knife-ec2", "~> 0.5.12"

  gem.add_development_dependency "rspec", "~> 2.10"
  gem.add_development_dependency "fakefs", "~> 0.4.0"
  gem.add_development_dependency "timecop", "~> 0.3.5"
end
