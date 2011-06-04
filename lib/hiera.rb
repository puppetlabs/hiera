class Hiera
    VERSION = "0.0.1"

    autoload :Scope, "hiera/scope"
    autoload :Config, "hiera/config"
    autoload :Backend, "hiera/backend"

    class NoDataFound < RuntimeError; end;

    class << self
        def version
            VERSION
        end

        def warn(msg)
            STDERR.puts("%s: %s" % [Time.now.to_s, msg])
        end
    end

    attr_reader :options, :config

    def initialize(options={})
        options[:config] ||= "/etc/hiera.yaml"

        @config = Config.load(options[:config])

        Config.load_backends
    end

    def lookup(key, default, scope, order_override=nil)
        Backend.lookup(key, default, scope, order_override)
    end
end
