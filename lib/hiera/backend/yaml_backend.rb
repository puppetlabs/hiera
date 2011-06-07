class Hiera
    module Backend
        class Yaml_backend
            def initialize
                require 'yaml'

                Hiera.debug("Hiera YAML backend starting")
            end

            def lookup(key, scope, order_override, resolution_type)
                answer = nil

                Hiera.debug("Looking up #{key} in YAML backend")

                datadir = Backend.datadir(:yaml, scope)

                raise "Cannot find data directory #{datadir}" unless File.directory?(datadir)

                Backend.datasources(scope, order_override) do |source|
                    unless answer
                        Hiera.debug("Looking for data source #{source}")

                        datafile = File.join([datadir, "#{source}.yaml"])

                        unless File.exist?(datafile)
                            Hiera.debug("Cannot find datafile #{datafile}, skipping")
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
