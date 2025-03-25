# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

# Load custom tasks
Dir.glob("#{File.dirname(__FILE__)}/lib/tasks/**/*.rake").each { |r| load r }

task default: %i[spec rubocop]
