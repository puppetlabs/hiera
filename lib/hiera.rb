require 'rubygems'
require 'yaml'

class Hiera
    VERSION = "0.2.1"

    autoload :Config, "hiera/config"
    autoload :Backend, "hiera/backend"
    autoload :Console_logger, "hiera/console_logger"
    autoload :Puppet_logger, "hiera/puppet_logger"

    class << self
        def version
            VERSION
        end

        # Loggers are pluggable, just provide a class called
        # Hiera::Foo_logger and respond to :warn and :debug
        #
        # See hiera-puppet for an example that uses the Puppet
        # loging system instead of our own
        def logger=(logger)
            loggerclass = "#{logger.capitalize}_logger"

            require "hiera/#{logger}_logger" unless constants.include?(loggerclass)

            @logger = const_get(loggerclass)
        rescue Exception => e
            @logger = Console_logger
            warn("Failed to load #{logger} logger: #{e.class}: #{e}")
        end

        # Parse a string like '%{foo}' against a supplied
        # scope and additional scope.  If either scope or
        # extra_scope includes the varaible 'foo' it will
        # be replaced else an empty string will be placed.
        #
        # If both scope and extra_data has "foo" scope
        # will win.  See hiera-puppet for an example of
        # this to make hiera aware of additional non scope
        # variables
        def parse_string(data, scope, extra_data={})
            return nil unless data

            tdata = data.clone

            if tdata.is_a?(String)
                while tdata =~ /%\{(.+?)\}/
                    var = $1
                    val = scope[var] || extra_data[var] || ""

                    # Puppet can return this for unknown scope vars
                    val = "" if val == :undefined

                    tdata.gsub!(/%\{#{var}\}/, val)
                end
            end

            return tdata
        end

        def warn(msg); @logger.warn(msg); end
        def debug(msg); @logger.debug(msg); end
    end

    attr_reader :options, :config

    # If the config option is a string its assumed to be a filename,
    # else a hash of what would have been in the YAML config file
    def initialize(options={}, scope={})
        options[:config] ||= "/etc/hiera.yaml"

        @config = Config.load(options[:config], scope)

        Config.load_backends
    end

    # Calls the backends to do the actual lookup.
    #
    # The scope can be anything that responds to [], if you have input
    # data like a Puppet Scope that does not you can wrap that data in a
    # class that has a [] method that fetches the data from your source.
    # See hiera-puppet for an example of this.
    #
    # The order-override will insert as first in the hierarchy a data source
    # of your choice.
    def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
        Backend.lookup(key, default, scope, order_override, resolution_type)
    end
end
