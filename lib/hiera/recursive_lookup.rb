# Allow for safe recursive lookup of values during variable interpolation.
#
# @api private
class Hiera::RecursiveLookup
  def initialize(scope, extra_data)
    @seen = []
    @scope = scope
    @extra_data = extra_data
  end

  def lookup(name, &block)
    if @seen.include?(name)
      raise Exception, "Interpolation loop detected in [#{@seen.join(', ')}]"
    end
    @seen.push(name)
    ret = yield(current_value)
    @seen.pop
    ret
  end

  def current_value
    name = @seen.last

    scope_val = @scope[name]
    if scope_val.nil? || scope_val == :undefined
      @extra_data[name]
    else
      scope_val
    end
  end
end
