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
    config = options[:config]
    if config.nil?
      # Look in codedir first, then confdir
      config = File.join(Util.code_dir, 'hiera.yaml')
      config = File.join(Util.config_dir, 'hiera.yaml') unless File.exist?(config)
    end
    @config = Config.load(config)

    Config.load_backends
  end

  # Calls the backends to do the actual lookup.
  #
  # The _scope_ can be anything that responds to `[]`, if you have input
  # data like a Puppet Scope that does not you can wrap that data in a
  # class that has a `[]` method that fetches the data from your source.
  # See hiera-puppet for an example of this.
  #
  # The order-override will insert as first in the hierarchy a data source
  # of your choice.
  #
  # Possible values for the _resolution_type_ parameter:
  #
  # - _:priority_ - This is the default. First found value is returned and no merge is performed
  # - _:array_ - An array merge lookup assembles a value from every matching level of the hierarchy. It retrieves all
  #     of the (string or array) values for a given key, then flattens them into a single array of unique values.
  #     If _priority_ lookup can be thought of as a “default with overrides” pattern, _array_ merge lookup can be though
  #     of as “default with additions.”
  # - _:hash_ - A hash merge lookup assembles a value from every matching level of the hierarchy. It retrieves all of
  #     the (hash) values for a given key, then merges the hashes into a single hash. Hash merge lookups will fail with
  #     an error if any of the values found in the data sources are strings or arrays. It only works when every value
  #     found is a hash. The actual merge behavior is determined by looking up the keys `:merge_behavior` and
  #     `:deep_merge_options` in the Hiera config. `:merge_behavior` can be set to `:deep`, :deeper` or `:native`
  #     (explained in detail below).
  # - _{ deep merge options }_ - Configured values for `:merge_behavior` and `:deep_merge_options`will be completely
  #     ignored. Instead the _resolution_type_ will be a `:hash` merge where the `:merge_behavior` will be the value
  #     keyed by `:behavior` in the given hash and the `:deep_merge_options` will be the remaining top level entries of
  #     that same hash.
  #
  # Valid behaviors for the _:hash_ resolution type:
  #
  # - _native_ - Performs a simple hash-merge by overwriting keys of lower lookup priority.
  # - _deeper_ - In a deeper hash merge, Hiera recursively merges keys and values in each source hash. For each key,
  #     if the value is:
  #        - only present in one source hash, it goes into the final hash.
  #        - a string/number/boolean and exists in two or more source hashes, the highest priority value goes into
  #          the final hash.
  #        - an array and exists in two or more source hashes, the values from each source are merged into a single
  #          array and de-duplicated (but not automatically flattened, as in an array merge lookup).
  #        - a hash and exists in two or more source hashes, the values from each source are recursively merged, as
  #          though they were source hashes.
  #        - mismatched between two or more source hashes, we haven’t validated the behavior. It should act as
  #          described in the deep_merge gem documentation.
  # - _deep_ - In a deep hash merge, Hiera behaves the same as for _deeper_, except that when a string/number/boolean
  #     exists in two or more source hashes, the lowest priority value goes into the final hash. This is considered
  #     largely useless and should be avoided. Use _deeper_ instead.
  #
  # The _merge_ can be given as a hash with the mandatory key `:strategy` to denote the actual strategy. This
  # is useful for the `:deeper` and `:deep` strategy since they can use additional options to control the behavior.
  # The options can be passed as top level keys in the `merge` parameter when it is a given as a hash. Recognized
  # options are:
  #
  #  - 'knockout_prefix' Set to string value to signify prefix which deletes elements from existing element. Defaults is _undef_
  #  - 'sort_merged_arrays' Set to _true_ to sort all arrays that are merged together. Default is _false_
  #  - 'merge_hash_arrays' Set to _true_ to merge hashes within arrays. Default is _false_
  #
  # @param key [String] The key to lookup
  # @param default [Object,nil] The value to return when there is no match for _key_
  # @param scope [#[],nil] The scope to use for the lookup
  # @param order_override [#[]] An override that will considered the first source of lookup
  # @param resolution_type [String,Hash<Symbol,String>] Symbolic resolution type or deep merge configuration
  # @return [Object] The found value or the given _default_ value
  def lookup(key, default, scope, order_override=nil, resolution_type=:priority)
    Backend.lookup(key, default, scope, order_override, resolution_type)
  end
end
