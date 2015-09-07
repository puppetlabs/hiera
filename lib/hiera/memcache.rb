require 'dalli'
require 'base64'

class Hiera
  class Memcache
    def initialize(servers)
      @memcache ||= new_client servers
    end

    def fetch(key, ttl, &block)
      uukey=Base64.encode64(key)
      @memcache ? @memcache.fetch(uukey, ttl, &block) : block.call
    end

    def new_client(servers)
      client = Dalli::Client.new(servers)
      begin
        client.alive!
      rescue StandardError
        false
      else
        client
      end
    end
  end
end
