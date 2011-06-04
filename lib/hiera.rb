require 'rubygems'

class Hiera
    VERSION = "0.0.1"

    autoload :Config, "hiera/config"
    autoload :Backend, "hiera/backend"
    autoload :Console_logger, "hiera/console_logger"

    class NoDataFound < RuntimeError; end;

    class << self
        def version
            VERSION
        end

        def logger=(logger)
            require "hiera/#{logger}_logger"

            @logger = const_get("#{logger.capitalize}_logger")
        rescue Exception => e
            @logger = Console_logger
            warn("Failed to load #{logger} logger: #{e.class}: #{e}")
        end

        def warn(msg); @logger.warn(msg); end
        def debug(msg); @logger.debug(msg); end
    end

    attr_reader :options, :config

    def initialize(options={})
        options[:config] ||= "/etc/hiera.yaml"

        @config = Config.load(options[:config])

        Config.load_backends
    end

    # TODO: resolution_type is to eventually support top down priority based
    #       lookups or bottom up merging type lookups like an ENC might need
    def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
        Backend.lookup(key, default, scope, order_override, resolution_type)
    end
end
