class Hiera
  module Backend
    class Yaml_backend
      def initialize(cache=nil)
        require 'yaml'
        Hiera.debug("Hiera YAML backend starting")

        @cache = cache || Filecache.new
      end

      def datafile(datadir, source, extension)
        file = File.join([datadir, "#{source}.#{extension}"])

        unless File.exist?(file)
          Hiera.debug("Cannot find datafile #{file}, skipping")

          return nil
        end

        return file
      end

      # recursive lookup for key/values inside data. This allows
      # foo::bar, foo::bar::buzz, or even foo::bar::buzz::blam
      def sub_lookup(data, classname, key, delimiter)
        if data.has_key? classname then
          if key.include?(delimiter) then
            result = sub_lookup(data[classname], key.split(delimiter).first,
                                key.sub(/^.*?#{delimiter}/,""), delimiter)
          else
            return data[classname][key]
          end
        else
          return nil
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        # If the hash_delimiter is turned on inside the hiera.yaml
        # then the user has indicated that they would like the nicer
        # YAML style of representing key/value pairs. As such, this 
        # means a bit more additional parsing later on, but not much
        delimiter = nil
        if Config[:yaml] and Config[:yaml].has_key? :hash_delimiter then
          delimiter = Config[:yaml][:hash_delimiter]
        end

        Hiera.debug("Looking up #{key} in YAML backend")

        datadir = Backend.datadir(:yaml, scope)

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          yamlfile = datafile(datadir, source, "yaml") || next

          next unless File.exist?(yamlfile)

          data = @cache.read_file(yamlfile, Hash) do |data|
            YAML.load(data)
          end

          next if data.empty?
          # Here is the conditional logic that will introspect keys/values
          # to find a match. This uses recursion to allow arbitrary depth.
          if delimiter and key.include? delimiter then
            result = sub_lookup(data, key.split(delimiter).first,
                                key.sub(/^.*?#{delimiter}/,""), delimiter)
            next unless result
            Hiera.debug("Found #{key} in #{source} inside hash")
            new_answer = Backend.parse_answer(result, scope)
          else
            next unless data.include?(key)
            # Extra logging that we found the key. This can be outputted
            # multiple times if the resolution type is array or hash but that
            # should be expected as the logging will then tell the user ALL the
            # places where the key is found.
            Hiera.debug("Found #{key} in #{source}")
            # for array resolution we just append to the array whatever
            # we find, we then goes onto the next file and keep adding to
            # the array
            #
            # for priority searches we break after the first found data item
            new_answer = Backend.parse_answer(data[key], scope)
          end

          case resolution_type
          when :array
            raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
            answer ||= []
            answer << new_answer
          when :hash
            raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
            answer ||= {}
            answer = Backend.merge_answer(new_answer,answer)
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
