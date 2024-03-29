# frozen_string_literal: true

require 'yard'
require 'rubocop/rake_task'
require 'bundler/gem_tasks'

require_relative 'lib/rvgp'

task default: 'all'

desc 'All'
task all: %i[test yard lint build]

desc 'Run the minitests'
task :test do
  Dir[RVGP::Gem.root('test/test*.rb')].sort.each { |f| require f }
end

desc 'Check code notation'
RuboCop::RakeTask.new(:lint) do |task|
  task.patterns = RVGP::Gem.ruby_files
  task.formatters += ['html']
  task.options += ['--fail-level', 'convention', '--out', 'rubocop.html']
end

YARD::Rake::YardocTask.new do |t|
  t.files = RVGP::Gem.ruby_files.reject do |f|
    %r{\A(?:(?:test|resources/skel)/.*|.*finance_gem_hacks\.rb\Z)}.match f
  end
  t.options = ['--no-private', '--protected', '--markup=markdown']
  t.stats_options = ['--list-undoc']
end
