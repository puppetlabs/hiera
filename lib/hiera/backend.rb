class Hiera
    module Backend
        class << self
            def datadir(backend, scope)
                parse_string(Config[backend.to_sym][:datadir] || "/var/lib/hiera", scope)
            end

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
                    yield(parse_string(source, scope))
                end
            end

            def parse_string(data, scope, extra_data={})
                return nil unless data

                tdata = data.clone

                if tdata.is_a?(String)
                    while tdata =~ /%\{(.+?)\}/
                        var = $1
                        val = scope[var] || extra_data[var] || ""

                        tdata.gsub!(/%\{#{var}\}/, val)
                    end
                end

                return tdata
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

                answer || parse_string(default, scope)
            end
        end
    end
end
