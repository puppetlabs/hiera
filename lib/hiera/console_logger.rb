class Hiera
  module Console_logger
    class << self
      def warn(msg)
        STDERR.puts("WARN: %s: %s" % [Time.now.to_s, msg])
      end

      def debug(msg)
        STDERR.puts("DEBUG: %s: %s" % [Time.now.to_s, msg])
      end
    end
  end
end
