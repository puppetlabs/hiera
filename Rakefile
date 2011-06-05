require 'rubygems'
require 'rake/gempackagetask'
require 'rspec/core/rake_task'

spec = Gem::Specification.new do |s|
  s.name = "hiera"
  s.version = "0.1.1"
  s.author = "R.I.Pienaar"
  s.email = "rip@devco.net"
  s.homepage = "https://github.com/ripienaar/hiera/"
  s.summary = "Light weight hierarcical data store"
  s.description = "A pluggable data store for hierarcical data"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.test_files = FileList["spec/**/*"].to_a
  s.has_rdoc = true
  s.executables = "hiera"
  s.default_executable = "hiera"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:test) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = File.read("spec/spec.opts").chomp || ""
end

task :default => [:test, :repackage]
