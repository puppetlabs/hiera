class Hiera
  module Puppet_logger
    class << self
      def suitable?
        defined?(::Puppet) == "constant"
      end

      def warn(msg)
        Puppet.notice("hiera(): #{msg}")
      end

      def debug(msg)
        Puppet.debug("hiera(): #{msg}")
      end
    end
  end
end
