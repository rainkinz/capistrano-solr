# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/solr/version'

Gem::Specification.new do |spec|
  spec.name          = "capistrano-solr"
  spec.version       = Capistrano::Solr::VERSION
  spec.authors       = ["rainkinz"]
  spec.email         = ["brendan.grainger@gmail.com"]

  spec.summary       = %q{Capistrano deployment tasks for Solr}
  spec.description   = %q{Capistrano deployment tasks for Solr}
  spec.homepage      = "https://github.com/rainkinz/capistrano-solr"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "capistrano", ">= 3.0"
  spec.add_dependency "tilt", "~> 2.0.2"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end
