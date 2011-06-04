require 'rubygems'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = "hiera"
  s.version = "0.0.1"
  s.author = "R.I.Pienaar"
  s.email = "rip@devco.net"
  s.homepage = "http://devco.net/"
  s.summary = "Light weight hierarcical data store"
  s.description = "A pluggable data store for hierarcical data"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.test_files = FileList["{test}/**/*test.rb"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md"]
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end
