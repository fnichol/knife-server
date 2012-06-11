# -*- encoding: utf-8 -*-
require File.expand_path('../lib/knife/server/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Fletcher Nichol"]
  gem.email         = ["fnichol@nichol.ca"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

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
end
