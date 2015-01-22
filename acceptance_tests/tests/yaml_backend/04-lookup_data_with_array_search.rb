begin test_name "Lookup data with Array search"

  agents.each do |agent|

    teardown do
      apply_manifest_on agent, <<-PP
      file { '/etc/puppet/hieradata':
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
      }
      file { '/etc/puppet/scope.yaml': ensure => absent }
      file { '/etc/puppet/scope.json': ensure => absent }
      PP
    end

    step 'Setup'
      apply_manifest_on agent, <<-PP
      file { '/etc/puppet/hieradata/production.yaml':
        ensure  => present,
        content => "---
          ntpservers: ['production.ntp.puppetlabs.com']
        "
      }

      file { '/etc/puppet/hieradata/global.yaml':
        ensure  => present,
        content => "---
          ntpservers: ['global.ntp.puppetlabs.com']
        "
      }

      file { '/etc/puppet/scope.yaml':
        ensure  => present,
        content => "---
          environment: production
        "
      }
      PP

    step "Try to lookup data using array search"
      on agent, hiera('ntpservers', '--yaml', '/etc/puppet/scope.yaml', '--array'),
        :acceptable_exit_codes => [0] do
        assert_output <<-OUTPUT
          STDOUT> ["production.ntp.puppetlabs.com", "global.ntp.puppetlabs.com"]
        OUTPUT
      end

  end

end
