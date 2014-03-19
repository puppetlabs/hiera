require 'hiera/backend'
require 'hiera/recursive_guard'

class Hiera::Interpolate
  class << self
    INTERPOLATION = /%+\{([^\}]*)\}/
    METHOD_INTERPOLATION = /%\{(scope|hiera)\(['"]([^"']*)["']\)\}/

    def interpolate(data, scope, extra_data)
      if data.is_a?(String)
        # Wrapping do_interpolation in a gsub block ensures we process
        # each interpolation site in isolation using separate recursion guards.
        data.gsub(INTERPOLATION) do |match|
          #Allow escaping of %{} to support litteral %{some_text} in hiera data.
          #Should support escaping of escapes so full list of scenarios looks like:
          #    %{var}      : 'value of var'
          #   %%{literal}  : '%{literal}'
          #  %%%{var}      : '%value of var'
          # %%%%{literal}  : '%%{literal}'

          percents = match.match(/^(%+)/)[1]
          if percents.length.even?
            match.gsub(/%%/,'%')
          else
            #Remove a % that represents the interpolation from percents
            #Of the remaining %'s sub each '%%' for '%' ('%%' is an escaped '%')
            #Remove all but one % from the match to feed into do_intepolation
            #add the percents (the escaped % signs back on so %%%{var} becomes %value
            percents.chop!
            percents.gsub!(/%%/,'%')
            match.sub!(/^%+/,'%')
            percents + do_interpolation(match, Hiera::RecursiveGuard.new, scope, extra_data).to_s
          end
        end
      else
        data
      end
    end

    def do_interpolation(data, recurse_guard, scope, extra_data)
      if data.is_a?(String) && (match = data.match(INTERPOLATION))
        interpolation_variable = match[1]
        recurse_guard.check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(data)
          interpolated_data = send(interpolate_method, data, key, scope, extra_data)
          do_interpolation(interpolated_data, recurse_guard, scope, extra_data)
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

      value
    end
    private :scope_interpolate

    def hiera_interpolate(data, key, scope, extra_data)
      Hiera::Backend.lookup(key, nil, scope, nil, :priority)
    end
    private :hiera_interpolate
  end
end
