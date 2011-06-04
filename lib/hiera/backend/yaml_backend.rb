class Hiera
    module Backend
        class Yaml_backend
            attr_reader :configkey

            def initialize
                require 'yaml'

                @configkey = :yaml

                Hiera.warn("YAML Starting")
            end

            def lookup(key, default, scope, order_override=nil)
                answer = nil

                Hiera.warn("Looking up #{key} with default #{default} in YAML backup")

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

                        if data[key].is_a?(String)
                            answer = Backend.parse_string(data[key], scope)
                        else
                            answer = data[key]
                        end
                    else
                        break
                    end
                end

                answer || default or raise(NoDataFound, "No match found for '#{key}' in any data file during hiera lookup")
            end
        end
    end
end
