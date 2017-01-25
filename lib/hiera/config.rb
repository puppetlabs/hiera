class Hiera::Config
  class << self
    ##
    # load takes a string or hash as input, strings are treated as filenames
    # hashes are stored as data that would have been in the config file
    #
    # Unless specified it will only use YAML as backend with a
    # hierarchy of 'nodes/%{::trusted.certname}' and 'common', and with a
    # console logger.
    #
    # @return [Hash] representing the configuration.
    def load(source)
      @config = {:backends => ["yaml"],
                 :hierarchy => ["nodes/%{::trusted.certname}", "common"],
                 :merge_behavior => :native }

      if source.is_a?(String)
        if File.exist?(source)
          config = begin
                     yaml_load_file(source)
                   rescue TypeError => detail
                     case detail.message
                     when /no implicit conversion from nil to integer/
                       false
                     else
                       raise detail
                     end
                   end
          @config.merge! config if config
        else
          raise "Config file #{source} not found"
        end
      elsif source.is_a?(Hash)
        @config.merge! source
      end

      @config[:backends] = [ @config[:backends] ].flatten

      if @config.include?(:logger)
        Hiera.logger = @config[:logger].to_s
      else
        @config[:logger] = "console"
        Hiera.logger = "console"
      end
    
      self.validate!

      @config
    end

    def validate!
      case @config[:merge_behavior]
      when :deep,'deep',:deeper,'deeper'
        begin
          require "deep_merge"
          require "deep_merge/rails_compat"
        rescue LoadError
          raise Hiera::Error, "Must have 'deep_merge' gem installed for the configured merge_behavior."
        end
      end
    end

    ##
    # yaml_load_file directly delegates to YAML.load_file and is intended to be
    # a private, internal method suitable for stubbing and mocking.
    #
    # @return [Object] return value of {YAML.load_file}
    def yaml_load_file(source)
      YAML.load_file(source)
    end
    private :yaml_load_file

    def load_backends
      @config[:backends].each do |backend|
        begin
          require "hiera/backend/#{backend.downcase}_backend"
        rescue LoadError => e
          raise "Cannot load backend #{backend}: #{e}"
        end
      end
    end

    def include?(key)
      @config.include?(key)
    end

    def [](key)
      @config[key]
    end
  end
end
