class Hiera
  module Backend
    class Json_backend
      def initialize(cache=nil)
        require 'json'

        Hiera.debug("Hiera JSON backend starting")

        @cache = cache || Filecache.new
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in JSON backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")

          jsonfile = Backend.datafile(:json, scope, source, "json") || next

          next unless File.exist?(jsonfile)

          data = @cache.read(jsonfile, Hash, {}) do |data|
            JSON.parse(data)
          end

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
            answer ||= []
            answer << new_answer
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
