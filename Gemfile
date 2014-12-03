# -*- encoding: utf-8 -*-
source "https://rubygems.org"

# Specify your gem's dependencies in knife-server.gemspec
gemspec

group :guard do
  gem "guard-rspec"
  gem "guard-rubocop"
end

group :test do
  # allow CI to override the version of Chef for matrix testing
  gem "chef", (ENV["CHEF_VERSION"] || ">= 0.10.10")
end
