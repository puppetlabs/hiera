class Hiera
  module Backend
    class Json_backend
      def initialize(cache=nil)
        require 'json'

        Hiera.debug("Hiera JSON backend starting")

        @cache = cache || Filecache.new
      end

      def lookup(key, scope, order_override, resolution_type, context)
        answer = nil
        found = false

        Hiera.debug("Looking up #{key} in JSON backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")

          jsonfile = Backend.datafile(:json, scope, source, "json") || next

          next unless File.exist?(jsonfile)

          data = @cache.read_file(jsonfile, Hash) do |data|
            JSON.parse(data)
          end

          next if data.empty?
          next unless data.include?(key)
          found = true

          # for array resolution we just append to the array whatever
          # we find, we then goes onto the next file and keep adding to
          # the array
          #
          # for priority searches we break after the first found data item
          new_answer = Backend.parse_answer(data[key], scope, {}, context)
          case resolution_type.is_a?(Hash) ? :hash : resolution_type
          when :array
            raise Exception, "Hiera type mismatch for key '#{key}': expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer ||= []
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch for key '#{key}': expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer ||= {}
            answer = Backend.merge_answer(new_answer, answer, resolution_type)
          else
            answer = new_answer
            break
          end
        end
        throw :no_such_key unless found
        return answer
      end
    end
  end
end
