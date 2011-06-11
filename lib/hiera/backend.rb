class Hiera
    module Backend
        class << self
            # Data lives in /var/lib/hiera by default.  If a backend
            # supplies a datadir in the config it will be used and
            # subject to variable expansion based on scope
            def datadir(backend, scope)
                backend = backend.to_sym
                default = "/var/lib/hiera"

                if Config.include?(backend)
                    parse_string(Config[backend][:datadir] || default, scope)
                else
                    parse_string(default, scope)
                end
            end

            # Finds the path to a datafile based on the Backend#datadir
            # and extension
            #
            # If the file is not found nil is returned
            def datafile(backend, scope, source, extension)
                file = File.join([datadir(backend, scope), "#{source}.#{extension}"])

                unless File.exist?(file)
                    Hiera.debug("Cannot find datafile #{file}, skipping")

                    return nil
                end

                return file
            end

            # Returns an appropriate empty answer dependant on resolution type
            def empty_answer(resolution_type)
                case resolution_type
                when :array
                    return []
                else
                    return nil
                end
            end

            # Constructs a list of data sources to search
            #
            # If you give it a specific hierarchy it will just use that
            # else it will use the global configured one, failing that
            # it will just look in the 'common' data source.
            #
            # An override can be supplied that will be pre-pended to the
            # hierarchy.
            #
            # The source names will be subject to variable expansion based
            # on scope
            def datasources(scope, override=nil, hierarchy=nil)
                if hierarchy
                    hierarchy = [hierarchy]
                elsif Config.include?(:hierarchy)
                    hierarchy = [Config[:hierarchy]].flatten
                else
                    hierarchy = ["common"]
                end

                hierarchy.insert(0, override) if override

                hierarchy.flatten.map do |source|
                    source = parse_string(source, scope)
                    yield(source) unless source == ""
                end
            end

            # Parse a string like '%{foo}' against a supplied
            # scope and additional scope.  If either scope or
            # extra_scope includes the varaible 'foo' it will
            # be replaced else an empty string will be placed.
            #
            # If both scope and extra_data has "foo" scope
            # will win.  See hiera-puppet for an example of
            # this to make hiera aware of additional non scope
            # variables
            def parse_string(data, scope, extra_data={})
                return nil unless data

                tdata = data.clone

                if tdata.is_a?(String)
                    while tdata =~ /%\{(.+?)\}/
                        var = $1
                        val = scope[var] || extra_data[var] || ""

                        # Puppet can return this for unknown scope vars
                        val = "" if val == :undefined

                        tdata.gsub!(/%\{#{var}\}/, val)
                    end
                end

                return tdata
            end

            # Parses a answer received from data files
            #
            # Ultimately it just pass the data through parse_string but
            # it makes some effort to handle arrays of strings as well
            def parse_answer(data, scope, extra_data={})
                if data.is_a?(String)
                    return parse_string(data, scope, extra_data)
                elsif data.is_a?(Hash)
                    answer = {}
                    data.each_pair do |key, val|
                        answer[key] = parse_answer(val, scope, extra_data)
                    end

                    return answer
                elsif data.is_a?(Array)
                    answer = []
                    data.each do |item|
                        answer << parse_answer(item, scope, extra_data)
                    end

                    return answer
                end
            end

            def resolve_answer(answer, resolution_type)
                case resolution_type
                when :array
                    [answer].flatten.uniq.sort
                else
                    answer
                end
            end

            # Calls out to all configured backends in the order they
            # were specified.  The first one to answer will win.
            #
            # This lets you declare multiple backends, a possible
            # use case might be in Puppet where a Puppet module declares
            # default data using in-module data while users can override
            # using JSON/YAML etc.  By layering the backends and putting
            # the Puppet one last you can override module author data
            # easily.
            #
            # Backend instances are cached so if you need to connect to any
            # databases then do so in your constructor, future calls to your
            # backend will not create new instances
            def lookup(key, default, scope, order_override, resolution_type)
                @backends ||= {}
                answer = nil

                Config[:backends].each do |backend|
                    if constants.include?("#{backend.capitalize}_backend")
                        @backends[backend] ||= Backend.const_get("#{backend.capitalize}_backend").new
                        answer = @backends[backend].lookup(key, scope, order_override, resolution_type)

                        break if answer
                    end
                end

                resolve_answer(answer, resolution_type) || parse_string(default, scope)
            end
        end
    end
end
