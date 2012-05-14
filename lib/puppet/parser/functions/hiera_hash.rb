module Puppet::Parser::Functions
  newfunction(:hiera_hash, :type => :rvalue) do |*args|
    if args[0].is_a?(Array)
      args = args[0]
    end

    raise(Puppet::ParseError, "Please supply a parameter to perform a Hiera lookup") if args.empty?

    key = args[0]
    default = args[1]
    override = args[2]

    configfile = File.join([File.dirname(Puppet.settings[:config]), "hiera.yaml"])

    raise(Puppet::ParseError, "Hiera config file #{configfile} not readable") unless File.exist?(configfile)

    require 'hiera'
    require 'hiera/scope'

    config = YAML.load_file(configfile)
    config[:logger] = "puppet"

    hiera = Hiera.new(:config => config)

    if self.respond_to?("{}")
      hiera_scope = self
    else
      hiera_scope = Hiera::Scope.new(self)
    end

    answer = hiera.lookup(key, default, hiera_scope, override, :hash)

    raise(Puppet::ParseError, "Could not find data item #{key} in any Hiera data file and no default supplied") if answer.empty?

    answer
  end
end
