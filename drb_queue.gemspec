# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'drb_queue/version'

Gem::Specification.new do |spec|
  spec.name          = "drb_queue"
  spec.version       = DRbQueue::VERSION
  spec.authors       = ["Andrew Warner"]
  spec.email         = ["wwarner.andrew@gmail.com"]
  spec.description   = %q{Simple drb-based queue/worker system}
  spec.summary       = %q{Simple drb-based queue/worker system}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency     "uuid", "~> 2.3.7"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "redis"
  spec.add_development_dependency "redis-namespace"
end
