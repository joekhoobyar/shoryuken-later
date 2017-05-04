# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shoryuken/later/version"

Gem::Specification.new do |spec|
  spec.name        = "shoryuken-later"
  spec.version     = Shoryuken::Later::VERSION
  spec.authors     = ["Joe Khoobyar"]
  spec.email       = ["joe@khoobyar.name"]
  spec.homepage    = "http://github.com/joekhoobyar/shoryuken-later"
  spec.summary     = 'A scheduling plugin (using Dynamo DB) for Shoryuken'
  spec.description = %Q{
    This gem provides a scheduling plugin (using Dynamo DB) for Shoryuken, as well as an ActiveJob adapter
  }

  spec.license = "LGPL-3.0"
  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = %w[shoryuken-later]
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_development_dependency "bundler", '>= 1.3.5'
  spec.add_development_dependency "rake",    '~> 10.0'
  spec.add_development_dependency "rspec",   '~> 3.0', '< 3.1'
  spec.add_development_dependency "pry-byebug"

  spec.add_dependency "timers", "~> 4.0.1"
  spec.add_dependency "shoryuken", "~> 3.0"
end
