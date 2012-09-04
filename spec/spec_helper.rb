$:.insert(0, File.join([File.dirname(__FILE__), "..", "lib"]))

require 'rubygems'
require 'rspec'
require 'mocha'
require 'hiera'
require 'tmpdir'

RSpec.configure do |config|
  config.mock_with :mocha
end

# In ruby 1.8.5 Dir does not have mktmpdir defined, so this monkey patches
# Dir to include the 1.8.7 definition of that method if it isn't already defined.
# Method definition borrowed from ruby-1.8.7-p357/lib/ruby/1.8/tmpdir.rb
unless Dir.respond_to?(:mktmpdir)
  def Dir.mktmpdir(prefix_suffix=nil, tmpdir=nil)
    case prefix_suffix
    when nil
      prefix = "d"
      suffix = ""
    when String
      prefix = prefix_suffix
      suffix = ""
    when Array
      prefix = prefix_suffix[0]
      suffix = prefix_suffix[1]
    else
      raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
    end
    tmpdir ||= Dir.tmpdir
    t = Time.now.strftime("%Y%m%d")
    n = nil
    begin
      path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      n ||= 0
      n += 1
      retry
    end

    if block_given?
      begin
        yield path
      ensure
        FileUtils.remove_entry_secure path
      end
    else
      path
    end
  end
end
