# Allow for safe recursive lookup of values during variable interpolation.
#
# @api private
class Hiera::RecursiveGuard
  def initialize
    @seen = []
  end

  def check(value, &block)
    if @seen.include?(value)
      raise Exception, "Interpolation loop detected in [#{@seen.join(', ')}]"
    end
    @seen.push(value)
    ret = yield
    @seen.pop
    ret
  end
end
