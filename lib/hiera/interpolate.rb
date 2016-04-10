require 'hiera/backend'
require 'hiera/recursive_guard'


class Hiera::InterpolationInvalidValue < StandardError; end

# @api private
class Hiera::Interpolate
  RX_INTERPOLATION = /%\{([^\}]*)\}/
  RX_ONLY_INTERPOLATION = /^%\{([^\}]*)\}$/
  RX_METHOD_AND_ARG = /^(\w+)\(([^)]*)\)$/

  EMPTY_INTERPOLATIONS = {
    '' => true,
    '::' => true,
    '""' => true,
    "''" => true,
    '"::"' => true,
    "'::'" => true
  }.freeze

  INTERPOLATION_METHODS = {
    'hiera' => :hiera_interpolate,
    'scope' => :scope_interpolate,
    'literal' => :literal_interpolate,
    'alias' => :alias_interpolate
  }.freeze

  class << self
    # These two patterns are never used but kept here anyway since they used to be public and therefore
    # must be considered API. The class is now marked @api private and these should be removed in a
    # future version
    #
    # @deprecated
    INTERPOLATION = /%\{([^\}]*)\}/

    # @deprecated
    METHOD_INTERPOLATION = /%\{(scope|hiera|literal|alias)\(['"]([^"']*)["']\)\}/

    def interpolate(data, scope, extra_data, context)
      if data.is_a?(String)
        # Wrapping do_interpolation in a gsub block ensures we process
        # each interpolation site in isolation using separate recursion guards.
        new_context = context.nil? ? {} : context.clone
        new_context[:recurse_guard] ||= Hiera::RecursiveGuard.new
        data.gsub(RX_INTERPOLATION) do |match|
          (interp_val, interpolate_method) = do_interpolation(match, scope, extra_data, new_context)

          if (interpolate_method == :alias_interpolate) && !interp_val.is_a?(String)
            return interp_val if data.match(RX_ONLY_INTERPOLATION)
            raise Hiera::InterpolationInvalidValue, "Cannot call alias in the string context"
          else
            interp_val
          end
        end
      else
        data
      end
    end

    def do_interpolation(data, scope, extra_data, context)
      if data.is_a?(String) && (match = data.match(RX_INTERPOLATION))
        interpolation_variable = match[1]

        # HI-494
        return ['', nil] if EMPTY_INTERPOLATIONS[interpolation_variable.strip]

        context[:recurse_guard].check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(interpolation_variable, context)
          interpolated_data = send(interpolate_method, data, key, scope, extra_data, context)

          # Halt recursion if we encounter a literal.
          return [interpolated_data, interpolate_method] if interpolate_method == :literal_interpolate

          [do_interpolation(interpolated_data, scope, extra_data, context)[0], interpolate_method]
        end
      else
        [data, nil]
      end
    end
    private :do_interpolation

    def get_interpolation_method_and_key(interpolation_variable, context)
      if (match = interpolation_variable.match(RX_METHOD_AND_ARG))
        Hiera.warn('Use of interpolation methods in hiera configuration file is deprecated') if context[:is_interpolate_config]
        method = match[1]
        method_sym = INTERPOLATION_METHODS[method]
        raise Hiera::InterpolationInvalidValue, "Invalid interpolation method '#{method}'" unless method_sym
        arg = match[2]
        match_data = arg.match(Hiera::QUOTED_KEY)
        raise Hiera::InterpolationInvalidValue, "Argument to interpolation method '#{method}' must be quoted, got '#{arg}'" unless match_data
        [method_sym, match_data[1] || match_data[2]]
      else
        [:scope_interpolate, interpolation_variable]
      end
    end
    private :get_interpolation_method_and_key

    def scope_interpolate(data, key, scope, extra_data, context)
      segments = Hiera::Util.split_key(key) { |problem| Hiera::InterpolationInvalidValue.new("#{problem} in interpolation expression: #{data}") }
      catch(:no_such_key) { return Hiera::Backend.qualified_lookup(segments, scope, key) }
      catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, extra_data, key) }
    end
    private :scope_interpolate

    def hiera_interpolate(data, key, scope, extra_data, context)
      Hiera::Backend.lookup(key, nil, scope, context[:order_override], :priority, context)
    end
    private :hiera_interpolate

    def literal_interpolate(data, key, scope, extra_data, context)
      key
    end
    private :literal_interpolate

    def alias_interpolate(data, key, scope, extra_data, context)
      Hiera::Backend.lookup(key, nil, scope, context[:order_override], :priority, context)
    end
    private :alias_interpolate
  end
end
