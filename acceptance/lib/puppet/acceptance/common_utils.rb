module Puppet
  module Acceptance
    module CommandUtils
      def ruby_command(host)
        "env PATH=\"#{host['privatebindir']}:${PATH}\" ruby"
      end
      module_function :ruby_command

      def gem_command(host)
        if host['platform'] =~ /windows/
          if host['platform'] =~ /-64$/ && host['ruby_arch'] != 'x64'
            "env SSL_CERT_FILE=\"C:/Program Files (x86)/Puppet Labs/Puppet/puppet/ssl/cert.pem\" PATH=\"#{host['privatebindir']}:${PATH}\" cmd /c gem"
          else
            "env SSL_CERT_FILE=\"C:/Program Files/Puppet Labs/Puppet/puppet/ssl/cert.pem\" PATH=\"#{host['privatebindir']}:${PATH}\" cmd /c gem"
          end
        else
          "env PATH=\"#{host['privatebindir']}:${PATH}\" gem"
        end
      end
      module_function :gem_command
    end
  end
end
