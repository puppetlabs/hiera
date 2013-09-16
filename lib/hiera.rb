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
  def lookup(key, default, scope, precedence=nil, order_override=nil, resolution_type=:priority)
    answer=nil

    # Allow cli to overwrite config file; this causes weirdness
    # so we have to overwrite backward when not set
    if !@config.nil?
      if !precedence.nil?
        @config[:precedence] = precedence
      else
        precedence = @config[:precedence]
      end
    end

    case precedence
    when :hierarchy
      # We have to deconstruct this a little and copy/paste this code (from hiera/backend.rb).
      Backend.datasources(scope, order_override) do |source|
        new_answer = Backend.lookup(key, default, scope, source, resolution_type)
        if not new_answer.nil?
          case resolution_type
          when :array
            raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer ||= []
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer ||= {}
            answer = Backend.merge_answer(new_answer,answer)
          else
            answer = new_answer
            break
          end
        end
      end
    else
      answer = Backend.lookup(key, default, scope, order_override, resolution_type)
    end

    answer
  end
end

