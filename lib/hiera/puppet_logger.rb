class Hiera
  module Puppet_logger
    unless defined? Puppet
      raise Exception, "Puppet is not currently loaded. This logger is only valid when hiera is running within puppet."
    end

    class << self
      def warn(msg)
        Puppet.notice("hiera(): #{msg}")
      end

      def debug(msg)
        Puppet.debug("hiera(): #{msg}")
      end
    end
  end
end
