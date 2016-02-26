require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks

RuboCop::RakeTask.new

RSpec::Core::RakeTask.new(:spec)

task default: [:rubocop, :spec]
