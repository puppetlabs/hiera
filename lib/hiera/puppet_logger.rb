class Hiera
  module Puppet_logger
    class << self
      def suitable?
        Kernel.const_defined?(:Puppet)
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
