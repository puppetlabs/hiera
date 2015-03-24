begin test_name "Lookup data with Array search"

  agents.each do |agent|
    codedir = agent.puppet['codedir']
    hieradatadir = File.join(codedir, 'hieradata')

    teardown do
      apply_manifest_on agent, <<-PP
      file { '#{hieradatadir}':
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
      }
      file { '#{codedir}/scope.yaml': ensure => absent }
      file { '#{codedir}/scope.json': ensure => absent }
      PP
    end

    step 'Setup'
      apply_manifest_on agent, <<-PP
      file { '#{hieradatadir}/production.yaml':
        ensure  => present,
        content => "---
          ntpservers: ['production.ntp.puppetlabs.com']
        "
      }

      file { '#{hieradatadir}/global.yaml':
        ensure  => present,
        content => "---
          ntpservers: ['global.ntp.puppetlabs.com']
        "
      }

      file { '#{codedir}/scope.yaml':
        ensure  => present,
        content => "---
          environment: production
        "
      }
      PP

    step "Try to lookup data using array search"
      on agent, hiera('ntpservers', '--yaml', "\"#{codedir}/scope.yaml\"", '--array'),
        :acceptable_exit_codes => [0] do
        assert_output <<-OUTPUT
          STDOUT> ["production.ntp.puppetlabs.com", "global.ntp.puppetlabs.com"]
        OUTPUT
      end

  end

end
