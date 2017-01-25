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
    def read(path, expected_type = Object, default=nil, &block)
      read_file(path, expected_type, &block)
    rescue TypeError => detail
      Hiera.debug("#{detail.message}, setting defaults")
      @cache[path][:data] = default
    rescue => detail
      error = "Reading data from #{path} failed: #{detail.class}: #{detail}"
      if default.nil?
        raise detail
      else
        Hiera.debug(error)
        @cache[path][:data] = default
      end
    end

    # Read a file when it changes. If a file is re-read and has not changed since the last time
    # then the last, processed, contents will be returned.
    #
    # The processed data can also be checked against an expected type. If the
    # type does not match a TypeError is raised.
    #
    # No error handling is done inside this method. Any failed reads or errors
    # in processing will be propagated to the caller
    def read_file(path, expected_type = Object)
      if stale?(path)
        data = File.read(path)
        @cache[path][:data] = block_given? ? yield(data) : data

        if !@cache[path][:data].is_a?(expected_type)
          raise TypeError, "Data retrieved from #{path} is #{@cache[path][:data].class} not #{expected_type}"
        end
      end

      @cache[path][:data]
    end

    private

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
