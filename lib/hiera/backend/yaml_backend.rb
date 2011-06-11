class Hiera
    module Backend
        class Yaml_backend
            def initialize
                require 'yaml'

                Hiera.debug("Hiera YAML backend starting")
            end

            def datadir(scope)
                datadir = Backend.datadir(:yaml, scope)

                raise "Cannot find data directory #{datadir}" unless File.directory?(datadir)

                return datadir
            end

            def datafile(scope, source)
                file = File.join([datadir(scope), "#{source}.yaml"])

                unless File.exist?(file)
                    Hiera.debug("Cannot find datafile #{file}, skipping")

                    return nil
                end

                return file
            end

            def empty_answer(resolution_type)
                case resolution_type
                when :array
                    return []
                else
                    return nil
                end
            end

            def lookup(key, scope, order_override, resolution_type)
                answer = empty_answer(resolution_type)

                Hiera.debug("Looking up #{key} in YAML backend")

                Backend.datasources(scope, order_override) do |source|
                    Hiera.debug("Looking for data source #{source}")

                    yamlfile = datafile(scope, source) || next

                    data = YAML.load_file(yamlfile)

                    next if data.empty?
                    next unless data.include?(key)

                    # for array resolution we just append to the array whatever
                    # we find, we then goes onto the next file and keep adding to
                    # the array
                    #
                    # for priority searches we break after the first found data item
                    case resolution_type
                    when :array
                        answer << Backend.parse_answer(data[key], scope)
                    else
                        answer = Backend.parse_answer(data[key], scope)
                        break
                    end
                end

                return answer
            end
        end
    end
end
