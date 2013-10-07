require 'hiera/backend'

class Hiera::Interpolate
  class << self
    INTERPOLATION = /%\{([^\}]*)\}/
    METHOD_INTERPOLATION = /%\{(scope|hiera)\(['"]([^"']*)["']\)\}/

    def interpolate(data, recurse_guard, scope, extra_data)
      if data.is_a?(String) && (match = data.match(INTERPOLATION))
        interpolation_variable = match[1]
        recurse_guard.check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(data)
          interpolated_data = send(interpolate_method, data, key, scope, extra_data)
          interpolate(interpolated_data, recurse_guard, scope, extra_data)
        end
      else
        data
      end
    end

    def get_interpolation_method_and_key(data)
      if (match = data.match(METHOD_INTERPOLATION))
        case match[1]
        when 'hiera' then [:hiera_interpolate, match[2]]
        when 'scope' then [:scope_interpolate, match[2]]
        end
      elsif (match = data.match(INTERPOLATION))
        [:scope_interpolate, match[1]]
      end
    end
    private :get_interpolation_method_and_key

    def scope_interpolate(data, key, scope, extra_data)
      value = scope[key]
      if value.nil? || value == :undefined
        value = extra_data[key]
      end
      data.sub(INTERPOLATION, value.to_s)
    end
    private :scope_interpolate

    def hiera_interpolate(data, key, scope, extra_data)
      value = Hiera::Backend.lookup(key, nil, scope, nil, :priority)
      data.sub(METHOD_INTERPOLATION, value)
    end
    private :hiera_interpolate
  end
end
