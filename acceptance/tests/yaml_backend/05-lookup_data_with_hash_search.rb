begin test_name "Lookup data with Hash search"

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

      file { '#{puppetcodedir}/scope.yaml':
        ensure  => present,
        content => "---
          environment: production
        "
      }
      PP

    step "Try to lookup data using hash search"
      on agent, hiera('users', '--yaml', "#{puppetcodedir}/scope.yaml", '--hash'),
        :acceptable_exit_codes => [0] do
        assert_match /joe[^}]+"uid"=>1000}/, result.output
        assert_match /pete[^}]+"uid"=>1001}/, result.output
      end

  end

end
