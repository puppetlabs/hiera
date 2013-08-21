require 'yaml'

class Hiera
  require "hiera/error"
  require "hiera/version"
  require "hiera/config"
  require "hiera/util"
  require "hiera/backend"
  require "hiera/console_logger"
  require "hiera/puppet_logger"
  require "hiera/noop_logger"
  require "hiera/fallback_logger"
  require "hiera/filecache"

  class << self
    attr_reader :logger

    # Loggers are pluggable, just provide a class called
    # Hiera::Foo_logger and respond to :warn and :debug
    #
    # See hiera-puppet for an example that uses the Puppet
    # loging system instead of our own
    def logger=(logger)
      require "hiera/#{logger}_logger"

      @logger = Hiera::FallbackLogger.new(
        Hiera.const_get("#{logger.capitalize}_logger"),
        Hiera::Console_logger)
    rescue Exception => e
      @logger = Hiera::Console_logger
      warn("Failed to load #{logger} logger: #{e.class}: #{e}")
    end

    def warn(msg); @logger.warn(msg); end
    def debug(msg); @logger.debug(msg); end
  end

  attr_reader :options, :config

  # If the config option is a string its assumed to be a filename,
  # else a hash of what would have been in the YAML config file
  def initialize(options={})
    options[:config] ||= File.join(Util.config_dir, 'hiera.yaml')

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
  def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
    Backend.lookup(key, default, scope, order_override, resolution_type)
  end
end

