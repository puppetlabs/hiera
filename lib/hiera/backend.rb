class Hiera
    module Backend
        class << self
            def datadir(backend, scope)
                parse_string(Config[backend.to_sym][:datadir] || "/var/lib/hiera", scope)
            end

            def parse_string(data, scope)
                tdata = data.clone

                while tdata =~ /%\{(.+?)\}/
                    tdata.gsub!(/%\{#{$1}\}/, scope[$1])
                end

                return tdata
            end

            def lookup(key, default, scope, order_override=nil)
                @backends ||= {}

                Config[:backends].each do |backend|
                    if constants.include?("#{backend.capitalize}_backend")
                        @backends[backend] ||= Backend.const_get("#{backend.capitalize}_backend").new
                        @backends[backend].lookup(key, default, scope, order_override)
                    end
                end
            end
        end
    end
end
