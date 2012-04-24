require 'rubygems'
require 'rubygems/package_task'
require 'rspec/core/rake_task'

Dir['tasks/**/*.rake'].each { |t| load t }

spec = Gem::Specification.new do |s|
  s.name = "hiera"
  # Tag the version you want to release via an annotated tag
  s.version = described_version
  s.author = "Puppet Labs"
  s.email = "info@puppetlabs.com"
  s.homepage = "https://github.com/puppetlabs/hiera/"
  s.summary = "Light weight hierarcical data store"
  s.description = "A pluggable data store for hierarcical data"
  s.files = FileList["{bin,lib}/**/*", "CHANGES.txt", "COPYING", "README.md"].to_a
  s.require_path = "lib"
  s.test_files = FileList["spec/**/*"].to_a
  s.has_rdoc = true
  s.executables = "hiera"
  s.default_executable = "hiera"
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar_gz = true
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = File.read("spec/spec.opts").chomp || ""
end

task :default => [:test, :repackage]
