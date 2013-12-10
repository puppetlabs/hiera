require 'hiera/util'
require 'hiera/interpolate'

begin
  require 'deep_merge'
rescue LoadError
end

class Hiera
  module Backend
    class << self
      # Data lives in /var/lib/hiera by default.  If a backend
      # supplies a datadir in the config it will be used and
      # subject to variable expansion based on scope
      def datadir(backend, scope)
        backend = backend.to_sym

        if Config[backend] && Config[backend][:datadir]
          dir = Config[backend][:datadir]
        else
          dir = Hiera::Util.var_dir
        end

        if !dir.is_a?(String)
          raise(Hiera::InvalidConfigurationError,
                "datadir for #{backend} cannot be an array")
        end

        parse_string(dir, scope)
      end

      # Finds the path to a datafile based on the Backend#datadir
      # and extension
      #
      # If the file is not found nil is returned
      def datafile(backend, scope, source, extension)
        datafile_in(datadir(backend, scope), source, extension)
      end

      # @api private
      def datafile_in(datadir, source, extension)
        file = File.join(datadir, "#{source}.#{extension}")

        if File.exist?(file)
          file
        else
          Hiera.debug("Cannot find datafile #{file}, skipping")
          nil
        end
      end

      # Constructs a list of data sources to search
      #
      # If you give it a specific hierarchy it will just use that
      # else it will use the global configured one, failing that
      # it will just look in the 'common' data source.
      #
      # An override can be supplied that will be pre-pended to the
      # hierarchy.
      #
      # The source names will be subject to variable expansion based
      # on scope
      def datasources(scope, override=nil, hierarchy=nil)
        if hierarchy
          hierarchy = [hierarchy]
        elsif Config.include?(:hierarchy)
          hierarchy = [Config[:hierarchy]].flatten
        else
          hierarchy = ["common"]
        end

        hierarchy.insert(0, override) if override

        hierarchy.flatten.map do |source|
          source = parse_string(source, scope)
          yield(source) unless source == "" or source =~ /(^\/|\/\/|\/$)/
        end
      end

      # Constructs a list of data files to search
      #
      # If you give it a specific hierarchy it will just use that
      # else it will use the global configured one, failing that
      # it will just look in the 'common' data source.
      #
      # An override can be supplied that will be pre-pended to the
      # hierarchy.
      #
      # The source names will be subject to variable expansion based
      # on scope
      #
      # Only files that exist will be returned. If the file is missing, then
      # the block will not receive the file.
      #
      # @yield [String, String] the source string and the name of the resulting file
      # @api public
      def datasourcefiles(backend, scope, extension, override=nil, hierarchy=nil)
        datadir = Backend.datadir(backend, scope)
        Backend.datasources(scope, override, hierarchy) do |source|
          Hiera.debug("Looking for data source #{source}")
          file = datafile_in(datadir, source, extension)

          if file
            yield source, file
          end
        end
      end

      # Parse a string like <code>'%{foo}'</code> against a supplied
      # scope and additional scope.  If either scope or
      # extra_scope includes the variable 'foo', then it will
      # be replaced else an empty string will be placed.
      #
      # If both scope and extra_data has "foo", then the value in scope
      # will be used.
      #
      # @param data [String] The string to perform substitutions on.
      #   This will not be modified, instead a new string will be returned.
      # @param scope [#[]] The primary source of data for substitutions.
      # @param extra_data [#[]] The secondary source of data for substitutions.
      # @return [String] A copy of the data with all instances of <code>%{...}</code> replaced.
      #
      # @api public
      def parse_string(data, scope, extra_data={})
        Hiera::Interpolate.interpolate(data, scope, extra_data)
      end

      # Parses a answer received from data files
      #
      # Ultimately it just pass the data through parse_string but
      # it makes some effort to handle arrays of strings as well
      def parse_answer(data, scope, extra_data={})
        if data.is_a?(Numeric) or data.is_a?(TrueClass) or data.is_a?(FalseClass)
          return data
        elsif data.is_a?(String)
          return parse_string(data, scope, extra_data)
        elsif data.is_a?(Hash)
          answer = {}
          data.each_pair do |key, val|
            interpolated_key = parse_string(key, scope, extra_data)
            answer[interpolated_key] = parse_answer(val, scope, extra_data)
          end

          return answer
        elsif data.is_a?(Array)
          answer = []
          data.each do |item|
            answer << parse_answer(item, scope, extra_data)
          end

          return answer
        end
      end

      def resolve_answer(answer, resolution_type)
        case resolution_type
        when :array
          [answer].flatten.uniq.compact
        when :hash
          answer # Hash structure should be preserved
        else
          answer
        end
      end

      # Merges two hashes answers with the configured merge behavior.
      #         :merge_behavior: {:native|:deep|:deeper}
      #
      # Deep merge options use the Hash utility function provided by [deep_merge](https://github.com/peritor/deep_merge)
      #
      #  :native => Native Hash.merge
      #  :deep   => Use Hash.deep_merge
      #  :deeper => Use Hash.deep_merge!
      #
      def merge_answer(left,right)
        case Config[:merge_behavior]
        when :deeper,'deeper'
          left.deep_merge!(right)
        when :deep,'deep'
          left.deep_merge(right)
        else # Native and undefined
          left.merge(right)
        end
      end

      # Calls out to all configured backends in the order they
      # were specified.  The first one to answer will win.
      #
      # This lets you declare multiple backends, a possible
      # use case might be in Puppet where a Puppet module declares
      # default data using in-module data while users can override
      # using JSON/YAML etc.  By layering the backends and putting
      # the Puppet one last you can override module author data
      # easily.
      #
      # Backend instances are cached so if you need to connect to any
      # databases then do so in your constructor, future calls to your
      # backend will not create new instances
      def lookup(key, default, scope, order_override, resolution_type)
        @backends ||= {}
        answer = nil

        Config[:backends].each do |backend|
          if constants.include?("#{backend.capitalize}_backend") || constants.include?("#{backend.capitalize}_backend".to_sym)
            @backends[backend] ||= Backend.const_get("#{backend.capitalize}_backend").new
            new_answer = @backends[backend].lookup(key, scope, order_override, resolution_type)

            if not new_answer.nil?
              case resolution_type
              when :array
                raise Exception, "Hiera type mismatch: expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
                answer ||= []
                answer << new_answer
              when :hash
                raise Exception, "Hiera type mismatch: expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
                answer ||= {}
                answer = merge_answer(new_answer,answer)
              else
                answer = new_answer
                break
              end
            end
          end
        end

        answer = resolve_answer(answer, resolution_type) unless answer.nil?
        answer = parse_string(default, scope) if answer.nil? and default.is_a?(String)

        return default if answer.nil?
        return answer
      end

      def clear!
        @backends = {}
      end
    end
  end
end
