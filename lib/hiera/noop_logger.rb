class Hiera
  module Noop_logger
    class << self
      def warn(msg);end
      def debug(msg);end
    end
  end
end
