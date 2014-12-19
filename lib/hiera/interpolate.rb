require 'hiera/backend'
require 'hiera/recursive_guard'


class Hiera::InterpolationInvalidValue < StandardError; end

class Hiera::Interpolate
  class << self
    INTERPOLATION = /%\{([^\}]*)\}/
    METHOD_INTERPOLATION = /%\{(scope|hiera|literal|alias)\(['"]([^"']*)["']\)\}/

    def interpolate(data, scope, override, extra_data)
      if data.is_a?(String)
        # Wrapping do_interpolation in a gsub block ensures we process
        # each interpolation site in isolation using separate recursion guards.
        data.gsub(INTERPOLATION) do |match|
          interp_val = do_interpolation(match, Hiera::RecursiveGuard.new, scope, override, extra_data)

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

    def do_interpolation(data, recurse_guard, scope, override, extra_data)
      if data.is_a?(String) && (match = data.match(INTERPOLATION))
        interpolation_variable = match[1]
        recurse_guard.check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(data)
          interpolated_data = send(interpolate_method, data, key, scope, override, extra_data)

          # Halt recursion if we encounter a literal.
          return interpolated_data if interpolate_method == :literal_interpolate

          do_interpolation(interpolated_data, recurse_guard, scope, override, extra_data)
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

    def scope_interpolate(data, key, scope, override, extra_data)
      value = scope[key]
      if value.nil? || value == :undefined
        value = extra_data[key]
      end

      value
    end
    private :scope_interpolate

    def hiera_interpolate(data, key, scope, override, extra_data)
      Hiera::Backend.lookup(key, nil, scope, override, :priority)
    end
    private :hiera_interpolate

    def literal_interpolate(data, key, scope, override, extra_data)
      key
    end
    private :literal_interpolate

    def alias_interpolate(data, key, scope, override, extra_data)
      Hiera::Backend.lookup(key, nil, scope, override, :priority)
    end
    private :alias_interpolate
  end
end
