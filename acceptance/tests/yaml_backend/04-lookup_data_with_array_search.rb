begin test_name "Lookup data with Array search"

  agents.each do |agent|

    puppetcodedir = agent.puppet()[:codedir]
    hieradatadir = "#{puppetcodedir}/hieradata"

    teardown do
      apply_manifest_on agent, <<-PP
      file { '#{hieradatadir}':
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
      }
      file { '#{puppetcodedir}/scope.yaml': ensure => absent }
      file { '#{puppetcodedir}/scope.json': ensure => absent }
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

      file { '#{puppetcodedir}/scope.yaml':
        ensure  => present,
        content => "---
          environment: production
        "
      }
      PP

    step "Try to lookup data using array search"
      on agent, hiera('ntpservers', '--yaml', "#{puppetcodedir}/scope.yaml", '--array'),
        :acceptable_exit_codes => [0] do
        assert_output <<-OUTPUT
          STDOUT> ["production.ntp.puppetlabs.com", "global.ntp.puppetlabs.com"]
        OUTPUT
      end

  end

end
