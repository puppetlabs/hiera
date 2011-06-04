class Hiera
    module Backend
        class Yaml_backend
            attr_reader :configkey

            def initialize
                require 'yaml'

                @configkey = :yaml

                Hiera.warn("YAML Starting")
            end

            def lookup(key, scope, order_override=nil)
                answer = nil

                Hiera.warn("Looking up #{key} in YAML backup")

                datadir = Backend.datadir(:yaml, scope)

                raise "Cannot find data directory #{datadir}" unless File.directory?(datadir)

                Backend.datasources(scope, order_override) do |source|
                    unless answer
                        Hiera.warn("Looking for data source #{source}")

                        datafile = File.join([datadir, "#{source}.yaml"])

                        unless File.exist?(datafile)
                            Hiera.warn("Cannot find datafile #{datafile}, skipping")
                            next
                        end

                        data = YAML.load_file(datafile)

                        next if data.empty?
                        next unless data.include?(key)

                        answer = Backend.parse_string(data[key], scope)
                    else
                        break
                    end
                end

                answer
            end
        end
    end
end
