require 'hiera/backend'
require 'hiera/recursive_guard'


class Hiera::InterpolationInvalidValue < StandardError; end

class Hiera::Interpolate
  class << self
    INTERPOLATION = /%\{([^\}]*)\}/
    METHOD_INTERPOLATION = /%\{(scope|hiera|literal|alias)\(['"]([^"']*)["']\)\}/

    def interpolate(data, scope, extra_data, context)
      if data.is_a?(String)
        # Wrapping do_interpolation in a gsub block ensures we process
        # each interpolation site in isolation using separate recursion guards.
        context ||= {}
        new_context = context.clone
        new_context[:recurse_guard] ||= Hiera::RecursiveGuard.new
        data.gsub(INTERPOLATION) do |match|
          interp_val = do_interpolation(match, scope, extra_data, new_context)

          # Get interp method in case we are aliasing
          if data.is_a?(String) && (match = data.match(INTERPOLATION))
            interpolate_method, key = get_interpolation_method_and_key(data)
          else
            interpolate_method = nil
          end

          if ( (interpolate_method == :alias_interpolate) and (!interp_val.is_a?(String)) )
            if data.match("^#{INTERPOLATION}$")
              return interp_val
            else
              raise Hiera::InterpolationInvalidValue, "Cannot call alias in the string context"
            end
          else
            interp_val
          end
        end
      else
        data
      end
    end

    def do_interpolation(data, scope, extra_data, context)
      if data.is_a?(String) && (match = data.match(INTERPOLATION))
        interpolation_variable = match[1]
        context[:recurse_guard].check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(data)
          interpolated_data = send(interpolate_method, data, key, scope, extra_data, context)

          # Halt recursion if we encounter a literal.
          return interpolated_data if interpolate_method == :literal_interpolate

          do_interpolation(interpolated_data, scope, extra_data, context)
        end
      else
        data
      end
    end
    private :do_interpolation

    def get_interpolation_method_and_key(data)
      if (match = data.match(METHOD_INTERPOLATION))
        case match[1]
        when 'hiera' then [:hiera_interpolate, match[2]]
        when 'scope' then [:scope_interpolate, match[2]]
        when 'literal' then [:literal_interpolate, match[2]]
        when 'alias' then [:alias_interpolate, match[2]]
        end
      elsif (match = data.match(INTERPOLATION))
        [:scope_interpolate, match[1]]
      end
    end
    private :get_interpolation_method_and_key

    def scope_interpolate(data, key, scope, extra_data, context)
      segments = key.split('.')
      catch(:no_such_key) { return Hiera::Backend.qualified_lookup(segments, scope) }
      catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, extra_data) }
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
