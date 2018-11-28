# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awsutils/version'

Gem::Specification.new do |spec|
  spec.name          = 'awsutils'
  spec.version       = AwsUtils::VERSION
  spec.authors       = ['Eric Herot']
  spec.email         = ['eric.rubygems@herot.com']
  spec.description   = %q{A set of tools for interacting with AWS}
  spec.summary       = %q{A set of tools for interacting with AWS (summary)}
  spec.homepage      = 'http://github.com/eherot'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.executables    = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'byebug'

  spec.add_dependency 'facets', '~> 2.9'
  spec.add_dependency 'rainbow', '~> 2.0'
  spec.add_dependency 'fog-aws', '~> 0.11.0'
  spec.add_dependency 'optimist' '~> 3.0'
  spec.add_dependency 'aws-sdk'
end
