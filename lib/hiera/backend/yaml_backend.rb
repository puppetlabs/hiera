class Hiera
  module Backend
    class Yaml_backend
      def initialize
        require 'yaml'
        Hiera.debug("Hiera YAML backend starting")
        @data  = Hash.new
        @cache = Hash.new
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = Backend.empty_answer(resolution_type)

        Hiera.debug("Looking up #{key} in YAML backend")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          yamlfile = Backend.datafile(:yaml, scope, source, "yaml") || next

          # If you call stale? BEFORE you do encounter the YAML.load_file line
          # it will populate the @cache variable and return true. The second
          # time you call it, it will return false because @cache has been
          # populated. Because of this there are two conditions to check:
          # is @data[yamlfile] populated AND is the cache stale.
          if @data[yamlfile]
            @data[yamlfile] = YAML.load_file(yamlfile) if stale?(yamlfile)
          else
            @data[yamlfile] = YAML.load_file(yamlfile)
          end

          next if ! @data[yamlfile]
          next if @data[yamlfile].empty?
          next unless @data[yamlfile].include?(key)
          # for array resolution we just append to the array whatever
          # we find, we then goes onto the next file and keep adding to
          # the array
          #
          # for priority searches we break after the first found data item
          new_answer = Backend.parse_answer(@data[yamlfile][key], scope)
          case resolution_type
          when :array
            raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer = new_answer.merge answer
          else
            answer = new_answer
            break
          end
        end

        return answer
      end

      def stale?(yamlfile)
        # NOTE: The mtime change in a file MUST be > 1 second before being
        #       recognized as stale. File mtime changes within 1 second will
        #       not be recognized.
        stat    = File.stat(yamlfile)
        current = { 'inode' => stat.ino, 'mtime' => stat.mtime, 'size' => stat.size }
        return false if @cache[yamlfile] == current

        @cache[yamlfile] = current
        return true
      end
    end
  end
end
