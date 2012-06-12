class Hiera
  module Util
    module_function

    def posix?
      require 'etc'
      Etc.getpwuid(0) != nil
    end

    def microsoft_windows?
      return false unless File::ALT_SEPARATOR
      
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
         File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'hiera', 'etc')
      else
        '/etc'
      end
    end

    def var_dir
      if microsoft_windows?
        File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'hiera', 'var')
      else
        '/var/lib/hiera'
      end
    end
  end
end

