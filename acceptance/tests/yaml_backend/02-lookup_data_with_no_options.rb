begin test_name "Lookup data using the default options"

  agents.each do |agent|
    codedir = agent.puppet['codedir']
    hieradatadir = File.join(codedir, 'hieradata')

    step 'Setup'
      apply_manifest_on agent, <<-PP
        file { '#{hieradatadir}':
          ensure  => directory,
          recurse => true,
          purge   => true,
          force   => true,
        }
    PP

      apply_manifest_on agent, <<-PP
        file { '#{hieradatadir}/global.yaml':
          ensure  => present,
          content => "---
            http_port: 8080
            ntp_servers: ['0.ntp.puppetlabs.com', '1.ntp.puppetlabs.com']
            users:
              pete:
                uid: 2000
              tom:
                uid: 2001
          "
        }
    PP

    step "Try to lookup string data"
      on agent, hiera("http_port"), :acceptable_exit_codes => [0] do
        assert_output <<-OUTPUT
          STDOUT> 8080
        OUTPUT
      end

      step "Try to lookup array data"
      on agent, hiera("ntp_servers"), :acceptable_exit_codes => [0] do
        assert_output <<-OUTPUT
          STDOUT> ["0.ntp.puppetlabs.com", "1.ntp.puppetlabs.com"]
        OUTPUT
      end

      step "Try to lookup hash data"
      on agent, hiera("users"), :acceptable_exit_codes => [0] do
        assert_match /tom[^}]+"uid"=>2001}/, result.output
        assert_match /pete[^}]+"uid"=>2000}/, result.output
      end

  end

end
