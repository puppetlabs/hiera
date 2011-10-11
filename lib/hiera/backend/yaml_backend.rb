class Hiera
    module Backend
        class Yaml_backend
            def initialize
                require 'yaml'

                Hiera.debug("Hiera YAML backend starting")
            end

            def lookup(key, scope, order_override, resolution_type)
                answer = Backend.empty_answer(resolution_type)

                Hiera.debug("Looking up #{key} in YAML backend")

                Backend.datasources(scope, order_override) do |source|
                    Hiera.debug("Looking for data source #{source}")

                    yamlfile = Backend.datafile(:yaml, scope, source, "yaml") || next

                    data = YAML.load_file(yamlfile)

                    next if ! data
                    next if data.empty?
                    next unless data.include?(key)

                    # for array resolution we just append to the array whatever
                    # we find, we then goes onto the next file and keep adding to
                    # the array
                    #
                    # for priority searches we break after the first found data item
                    new_answer = Backend.parse_answer(data[key], scope)
                    case resolution_type
                    when :array
                        raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
                        answer << new_answer
                    when :hash
                        raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
                        answer = new_answer.merge answer
                    else
                        answer = new_answer
                        break
                    end
                end

                return answer
            end
        end
    end
end
