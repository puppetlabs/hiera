# Select from a given list of loggers the first one that
# it suitable and use that as the actual logger
#
# @api private
class Hiera::FallbackLogger
  # Chooses the first suitable logger. For all of the loggers that are
  # unsuitable it will issue a warning using the suitable logger stating that
  # the unsuitable logger is not being used.
  #
  # @param implementations [Array<Hiera::Logger>] the implementations to choose from
  # @raises when there are no suitable loggers
  def initialize(*implementations)
    warnings = []
    @implementation = implementations.find do |impl|
      if impl.respond_to?(:suitable?)
        if impl.suitable?
          true
        else
          warnings << "Not using #{impl.name}. It does not report itself to be suitable."
          false
        end
      else
        true
      end
    end

    if @implementation.nil?
      raise "No suitable logging implementation found."
    end

    warnings.each { |message| warn(message) }
  end

  def warn(message)
    @implementation.warn(message)
  end

  def debug(message)
    @implementation.debug(message)
  end
end
