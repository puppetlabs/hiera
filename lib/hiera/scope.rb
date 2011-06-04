module Hiera
    class Scope
        attr_reader :input, :type

        def initialize(input)
            @input = input

            if @input.respond_to?(:lookupvar)
                @type = :puppet
            elsif @input.respond_to?("[]")
                @type = :hash
            else
                raise "Input data source class #{input.class} is not supported"
            end
        end

        def [](key)
            if @type == :puppet
                @input.lookupvar(key)
            else
                @input[key]
            end
        end

        def include?(key)
            if @type == :puppet
                @input.lookupvar(key) == ""
            else
                @input.include?(key)
            end
        end
    end
end
