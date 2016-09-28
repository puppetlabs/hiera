class Hiera

  # Matches a key that is quoted using a matching pair of either single or double quotes.
  QUOTED_KEY = /^(?:"([^"]+)"|'([^']+)')$/
  QUOTES = /[",]/

  module Util
    module_function

    def posix?
      require 'etc'
      Etc.getpwuid(0) != nil
    end

    def microsoft_windows?
      return false unless file_alt_separator

      begin
        require 'win32/dir'
        true
      rescue LoadError => err
        warn "Cannot run on Microsoft Windows without the win32-dir gem: #{err}"
        false
      end
    end

    def config_dir
      if microsoft_windows?
         File.join(common_appdata, 'PuppetLabs', 'puppet', 'etc')
      else
        '/etc/puppetlabs/puppet'
      end
    end

    def code_dir
      if microsoft_windows?
        File.join(common_appdata, 'PuppetLabs', 'code')
      else
        '/etc/puppetlabs/code'
      end
    end

    def var_dir
      File.join(code_dir, 'environments' , '%{environment}' , 'hieradata')
    end

    def file_alt_separator
      File::ALT_SEPARATOR
    end

    def common_appdata
      Dir::COMMON_APPDATA
    end

    def split_key(key)
      segments = key.split(/(?:"([^"]+)"|'([^']+)'|([^'".]+))/)
      if segments.empty?
        # Only happens if the original key was an empty string
        ''
      elsif segments.shift == ''
        count = segments.size
        raise yield('Syntax error') unless count > 0

        segments.keep_if { |seg| seg != '.' }
        raise yield('Syntax error') unless segments.size * 2 == count + 1
        segments
      else
        raise yield('Syntax error')
      end
    end
  end
end

