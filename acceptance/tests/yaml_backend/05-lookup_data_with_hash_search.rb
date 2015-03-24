begin test_name "Lookup data with Hash search"

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
          users:
            joe:
              uid: 1000
        "
      }

      file { '#{hieradatadir}/global.yaml':
        ensure  => present,
        content => "---
          users:
            pete:
              uid: 1001
        "
      }

      file { '#{codedir}/scope.yaml':
        ensure  => present,
        content => "---
          environment: production
        "
      }
      PP

    step "Try to lookup data using hash search"
      on agent, hiera('users', '--yaml', "\"#{codedir}/scope.yaml\"", '--hash'),
        :acceptable_exit_codes => [0] do
        assert_match /joe[^}]+"uid"=>1000}/, result.output
        assert_match /pete[^}]+"uid"=>1001}/, result.output
      end

  end

end
