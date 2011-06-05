class Hiera::Config
    class << self
        # Takes a string or hash as input, strings are treated as filenames
        # hashes are stored as data that would have been in the config file
        #
        # Unless specified it will only use YAML as backend with a single
        # 'common' hierarchy and console logger
        def load(source)
            @config = {:backends => "yaml",
                       :hierarchy => "common"}

            if source.is_a?(String)
                raise "Config file #{source} not found" unless File.exist?(source)

                @config.merge! YAML.load_file(source)
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

            @config
        end

        def load_backends
            @config[:backends].each do |backend|
                begin
                    require "hiera/backend/#{backend.downcase}_backend"
                rescue LoadError => e
                    Hiera.warn "Cannot load backend #{backend}: #{e}"
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
