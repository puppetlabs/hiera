class Hiera::Config
    class << self
        def load(source)
            default_config = {:backends => "yaml",
                              :hierarchy => "common"}

            if source.is_a?(String)
                raise "Config file #{source} not found" unless File.exist?(source)

                @config = YAML.load_file(source)
            elsif source.is_a?(Hash)
                @config = source
            end

            default_config.merge! @config

            @config[:backends] = [ @config[:backends] ].flatten

            @config
        end

        def load_backends
            [@config[:backends]].flatten.each do |backend|
                begin
                    require "hiera/backend/#{backend.downcase}_backend"
                rescue LoadError => e
                    Hiera.warn "Cannot load backend #{backend}: #{e}"
                end
            end
        end

        def [](key)
            @config[key] || {}
        end
    end
end
