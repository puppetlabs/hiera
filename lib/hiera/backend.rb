class Hiera
    module Backend
        class << self
            def datadir(backend, scope)
                parse_string(Config[backend.to_sym][:datadir] || "/var/lib/hiera", scope)
            end

            def datasources(scope, override=nil, precedence=nil)
                if precedence
                    precedence = [precedence]
                elsif Config.include?(:precedence)
                    precedence = [Config[:precedence]]
                else
                    precedence = ["common"]
                end

                precedence.insert(0, override) if override

                sources = []

                precedence.flatten.map do |source|
                    yield(parse_string(source, scope))
                end
            end

            def parse_string(data, scope)
                tdata = data.clone

                while tdata =~ /%\{(.+?)\}/
                    var = $1
                    val = scope[var] || ""

                    tdata.gsub!(/%\{#{var}\}/, val)
                end

                return tdata
            end

            def lookup(key, default, scope, order_override=nil)
                @backends ||= {}
                answer = nil

                Config[:backends].each do |backend|
                    if constants.include?("#{backend.capitalize}_backend")
                        begin
                            @backends[backend] ||= Backend.const_get("#{backend.capitalize}_backend").new
                            answer = @backends[backend].lookup(key, default, scope, order_override)

                            break if answer
                        rescue NoDataFound
                        end
                    end
                end

                answer
            end
        end
    end
end
