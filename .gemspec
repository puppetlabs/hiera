# -*- encoding: utf-8 -*-
#
# PLEASE NOTE - This gemspec is intended for use with Bundler from source, not
# for building the official Gem.  Please see the [packaging
# repository](https://github.com/puppetlabs/packaging) for information on how
# to build release packages.

begin
  require 'hiera/version'
rescue LoadError
  $LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))
  require 'hiera/version'
end

Gem::Specification.new do |s|
  s.name = "hiera"
  version = Hiera.version
  mdata = version.match(/(\d+\.\d+\.\d+)/)
  s.version = mdata ? mdata[1] : version

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Puppet Labs"]
  s.date = "2013-04-03"
  s.description = "A pluggable data store for hierarcical data"
  s.email = "info@puppetlabs.com"
  s.executables = ["hiera"]
  s.files = ["bin/hiera"]
  s.homepage = "https://github.com/puppetlabs/hiera"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.25"
  s.summary = "Light weight hierarchical data store"
end
