class Hiera
  module Util
    module Win32
      if !!File::ALT_SEPARATOR
        require 'fiddle/import'
        require 'fiddle/types'

        # import, dlload, include and typealias must be ordered this way
        extend Fiddle::Importer
        dlload 'shell32'
        include Fiddle::Win32Types # adds HWND, HANDLE, DWORD type aliases
        typealias 'LPWSTR', 'wchar_t*'
        typealias 'LONG', 'long'
        typealias 'HRESULT','LONG'

        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx
        # HRESULT SHGetFolderPath(
        #   _In_  HWND   hwndOwner,
        #   _In_  int    nFolder,
        #   _In_  HANDLE hToken,
        #   _In_  DWORD  dwFlags,
        #   _Out_ LPTSTR pszPath
        # );
        extern 'HRESULT SHGetFolderPathW(HWND, int, HANDLE, DWORD, LPWSTR)'

        COMMON_APPDATA = 0x0023
        S_OK           = 0x0
        MAX_PATH       = 260;

        def self.get_common_appdata
          # null terminated MAX_PATH string in wchar (i.e. 2 bytes per char)
          buffer = 0.chr * ((MAX_PATH + 1) * 2)
          result = SHGetFolderPathW(0, COMMON_APPDATA, 0, 0, buffer)
          raise "Could not find COMMON_APPDATA path - HRESULT: #{result}" unless result == S_OK
          buffer.force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8).strip
        end
      end
    end
  end
end
