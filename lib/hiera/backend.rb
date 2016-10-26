require 'hiera/util'
require 'hiera/interpolate'

begin
  require 'deep_merge/rails_compat'
rescue LoadError
end

class Hiera
  module Backend
    class Backend1xWrapper
      def initialize(wrapped)
        @wrapped = wrapped
      end

      def lookup(key, scope, order_override, resolution_type, context)
        Hiera.debug("Using Hiera 1.x backend API to access instance of class #{@wrapped.class.name}. Lookup recursion will not be detected")
        value = @wrapped.lookup(key, scope, order_override, resolution_type.is_a?(Hash) ? :hash : resolution_type)

        # The most likely cause when an old backend returns nil is that the key was not found. In any case, it is
        # impossible to know the difference between that and a found nil. The throw here preserves the old behavior.
        throw (:no_such_key) if value.nil?
        value
      end
    end

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

        interpolate_config(dir, scope, nil)
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
          source = interpolate_config(source, scope, override)
          if source == "" or source =~ /(^\/|\/\/|\/$)/
            Hiera.debug("Ignoring bad definition in :hierarchy: \'#{source}\'")
          else
            yield(source)
          end
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
      # @param context [#[]] Context can include :recurse_guard and :order_override.
      # @return [String] A copy of the data with all instances of <code>%{...}</code> replaced.
      #
      # @api public
      def parse_string(data, scope, extra_data={}, context={:recurse_guard => nil, :order_override => nil})
        Hiera::Interpolate.interpolate(data, scope, extra_data, context)
      end

      # Parses a answer received from data files
      #
      # Ultimately it just pass the data through parse_string but
      # it makes some effort to handle arrays of strings as well
      def parse_answer(data, scope, extra_data={}, context={:recurse_guard => nil, :order_override => nil})
        if data.is_a?(Numeric) or data.is_a?(TrueClass) or data.is_a?(FalseClass)
          return data
        elsif data.is_a?(String)
          return parse_string(data, scope, extra_data, context)
        elsif data.is_a?(Hash)
          answer = {}
          data.each_pair do |key, val|
            interpolated_key = parse_string(key, scope, extra_data, context)
            answer[interpolated_key] = parse_answer(val, scope, extra_data, context)
          end

          return answer
        elsif data.is_a?(Array)
          answer = []
          data.each do |item|
            answer << parse_answer(item, scope, extra_data, context)
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

      # Merges two hashes answers with the given or configured merge behavior. Behavior can be given
      # by passing _resolution_type_ as a Hash
      #
      #  :merge_behavior: {:native|:deep|:deeper}
      #
      # Deep merge options use the Hash utility function provided by [deep_merge](https://github.com/danielsdeleo/deep_merge)
      # It uses the compatibility mode [deep_merge](https://github.com/danielsdeleo/deep_merge#using-deep_merge-in-rails)
      #
      #  :native => Native Hash.merge
      #  :deep   => Use Hash.deeper_merge
      #  :deeper => Use Hash.deeper_merge!
      #
      # @param left [Hash] left side of the merge
      # @param right [Hash] right side of the merge
      # @param resolution_type [String,Hash] The merge type, or if hash, the merge behavior and options
      # @return [Hash] The merged result
      # @see Hiera#lookup
      #
      def merge_answer(left,right,resolution_type=nil)
        behavior, options =
          if resolution_type.is_a?(Hash)
            merge = resolution_type.clone
            [merge.delete(:behavior), merge]
          else
            [Config[:merge_behavior], Config[:deep_merge_options] || {}]
          end

        case behavior
        when :deeper,'deeper'
          left.deeper_merge!(right, options)
        when :deep,'deep'
          left.deeper_merge(right, options)
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

      # @param key [String] The key to lookup. May be quoted with single or double quotes to avoid subkey traversal on dot characters
      # @param scope [#[]] The primary source of data for substitutions.
      # @param order_override [#[],nil] An override that will be pre-pended to the hierarchy definition.
      # @param resolution_type [Symbol,Hash,nil] One of :hash, :array,:priority or a Hash with deep merge behavior and options
      # @param context [#[]] Context used for internal processing
      # @return [Object] The value that corresponds to the given key or nil if no such value cannot be found
      #
      def lookup(key, default, scope, order_override, resolution_type, context = {:recurse_guard => nil})
        @backends ||= {}
        answer = nil

        # order_override is kept as an explicit argument for backwards compatibility, but should be specified
        # in the context for internal handling.
        context ||= {}
        order_override ||= context[:order_override]
        context[:order_override] ||= order_override

        strategy = resolution_type.is_a?(Hash) ? :hash : resolution_type

        segments = Util.split_key(key) { |problem| ArgumentError.new("#{problem} in key: #{key}") }
        subsegments = nil
        if segments.size > 1
          unless strategy.nil? || strategy == :priority
            raise ArgumentError, "Resolution type :#{strategy} is illegal when accessing values using dotted keys. Offending key was '#{key}'"
          end
          subsegments = segments.drop(1)
        end

        found = false
        Config[:backends].each do |backend|
          backend_constant = "#{backend.capitalize}_backend"
          if constants.include?(backend_constant) || constants.include?(backend_constant.to_sym)
            backend = (@backends[backend] ||= find_backend(backend_constant))
            found_in_backend = false
            new_answer = catch(:no_such_key) do
              if subsegments.nil? 
                value = backend.lookup(segments[0], scope, order_override, resolution_type, context)
              elsif backend.respond_to?(:lookup_with_segments)
                value = backend.lookup_with_segments(segments, scope, order_override, resolution_type, context)
              else
                value = backend.lookup(segments[0], scope, order_override, resolution_type, context)
                value = qualified_lookup(subsegments, value, key) unless subsegments.nil?
              end
              found_in_backend = true
              value
            end
            next unless found_in_backend
            found = true

            case strategy
            when :array
              raise Exception, "Hiera type mismatch for key '#{key}': expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
              answer ||= []
              answer << new_answer
            when :hash
              raise Exception, "Hiera type mismatch for key '#{key}': expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
              answer ||= {}
              answer = merge_answer(new_answer, answer, resolution_type)
            else
              answer = new_answer
              break
            end
          end
        end

        answer = resolve_answer(answer, strategy) unless answer.nil?
        answer = parse_string(default, scope, {}, context) if !found && default.is_a?(String)

        return default if !found && answer.nil?
        return answer
      end

      def clear!
        @backends = {}
      end

      def qualified_lookup(segments, hash, full_key = nil)
        value = hash
        segments.each do |segment|
          throw :no_such_key if value.nil?
          if segment =~ /^[0-9]+$/
            segment = segment.to_i
            unless value.instance_of?(Array)
              suffix = full_key.nil? ? '' : " from key '#{full_key}'"
              raise Exception,
                "Hiera type mismatch: Got #{value.class.name} when Array was expected to access value using '#{segment}'#{suffix}"
            end
            throw :no_such_key unless segment < value.size
          else
            unless value.respond_to?(:'[]') && !(value.instance_of?(Array) || value.instance_of?(String))
              suffix = full_key.nil? ? '' : " from key '#{full_key}'"
              raise Exception,
                "Hiera type mismatch: Got #{value.class.name} when a hash-like object was expected to access value using '#{segment}'#{suffix}"
            end
            throw :no_such_key unless value.include?(segment)
          end
          value = value[segment]
        end
        value
      end

      def find_backend(backend_constant)
        backend = Backend.const_get(backend_constant).new
        return backend.method(:lookup).arity == 4 ? Backend1xWrapper.new(backend) : backend
      end
      private :find_backend

      def interpolate_config(entry, scope, override)
        if @config_lookup_context.nil?
          @config_lookup_context = { :is_interpolate_config => true, :order_override => override, :recurse_guard => Hiera::RecursiveGuard.new }
          begin
            Hiera::Interpolate.interpolate(entry, scope, {}, @config_lookup_context)
          ensure
            @config_lookup_context = nil
          end
        else
          # Nested call (will happen when interpolate method 'hiera' is used)
          Hiera::Interpolate.interpolate(entry, scope, {}, @config_lookup_context.merge(:order_override => override))
        end
      end
    end
  end
end
