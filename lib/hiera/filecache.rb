class Hiera
  class Filecache
    def initialize
      @cache = {}
    end

    # Reads a file, optionally parse it in some way check the
    # output type and set a default
    #
    # Simply invoking it this way will return the file contents
    #
    #    data = read("/some/file")
    #
    # But as most cases of file reading in hiera involves some kind
    # of parsing through a serializer there's some help for those
    # cases:
    #
    #    data = read("/some/file", Hash, {}) do |data|
    #       JSON.parse(data)
    #    end
    #
    # In this case it will read the file, parse it using JSON then
    # check that the end result is a Hash, if it's not a hash or if
    # reading/parsing fails it will return {} instead
    #
    # Prior to calling this method you should be sure the file exist
    def read(path, expected_type=nil, default=nil)
      @cache[path] ||= {:data => nil, :meta => path_metadata(path)}

      if File.exist?(path) && !@cache[path][:data] || stale?(path)
        if block_given?
          begin
            @cache[path][:data] = yield(File.read(path))
          rescue => e
            Hiera.debug("Reading data from %s failed: %s: %S" % [path, e.class, e.to_s])
            @cache[path][:data] = default
          end
        else
          @cache[path][:data] = File.read(path)
        end
      end

      if block_given? && !expected_type.nil?
        unless @cache[path][:data].is_a?(expected_type)
          Hiera.debug("Data retrieved from %s is not a %s, setting defaults" % [path, expected_type])
          @cache[path][:data] = default
        end
      end

      @cache[path][:data]
    end

    def stale?(path)
      meta = path_metadata(path)

      @cache[path] ||= {:data => nil, :meta => nil}

      if @cache[path][:meta] == meta
        return false
      else
        @cache[path][:meta] = meta
        return true
      end
    end

    # This is based on the old caching in the YAML backend and has a
    # resolution of 1 second, changes made within the same second of
    # a previous read will be ignored
    def path_metadata(path)
      stat = File.stat(path)
      {:inode => stat.ino, :mtime => stat.mtime, :size => stat.size}
    end
  end
end
