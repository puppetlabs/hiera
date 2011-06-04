module Hiera::Backend
    class Yaml_backend
        def initialize
            Hiera.warn("YAML Starting")
        end

        def lookup(key, default, scope, order_override=nil)
            Hiera.warn("Looking up #{key} with default #{default} in YAML backup")
        end
    end
end
