class Hiera
  module Backend
    class Json_backend
      def initialize
        require 'json'

        Hiera.debug("Hiera JSON backend starting")
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in JSON backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")

          jsonfile = Backend.datafile(:json, scope, source, "json") || next

          data = JSON.parse(File.read(jsonfile))

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
            answer = Backend.parse_answer(data[key], scope)
            break
          end
        end

        return answer
      end
    end
  end
end
