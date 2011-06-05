require 'rubygems'
require 'yaml'

class Hiera
    VERSION = "0.1.0"

    autoload :Config, "hiera/config"
    autoload :Backend, "hiera/backend"
    autoload :Console_logger, "hiera/console_logger"

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

        def warn(msg); @logger.warn(msg); end
        def debug(msg); @logger.debug(msg); end
    end

    attr_reader :options, :config

    # If the config option is a string its assumed to be a filename,
    # else a hash of what would have been in the YAML config file
    def initialize(options={})
        options[:config] ||= "/etc/hiera.yaml"

        @config = Config.load(options[:config])

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
    #
    # TODO: resolution_type is to eventually support top down priority based
    #       lookups or bottom up merging type lookups like an ENC might need
    def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
        Backend.lookup(key, default, scope, order_override, resolution_type)
    end
end
