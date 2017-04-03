test_name "Command-line lookup should resolve based on fact values from facter run"

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

  osfamily = (on agent, facter('osfamily')).stdout.chomp

  apply_manifest_on agent, <<-PP
file { '#{codedir}/hiera.yaml':
  ensure  => present,
  content => '---
    :backends:
      - "yaml"
    :logger: "console"
    :hierarchy:
      - "osfamily/%{::osfamily}"
      - "%{environment}"
      - "global"

    :yaml:
      :datadir: "#{hieradatadir}"
  '
}

file { ['#{hieradatadir}', '#{hieradatadir}/osfamily']:
  ensure => directory,
}

file { '#{hieradatadir}/global.yaml':
  ensure => present,
  content => "---
    foo: zan
  "
}

file { '#{hieradatadir}/osfamily/#{osfamily}.yaml':
  ensure => present,
  content => "---
    foo: bar
  "
}
PP

  on agent, hiera('foo', "osfamily=#{osfamily}") do
    assert_match /bar/, result.stdout
  end

  on agent, hiera('foo', "::osfamily=#{osfamily}") do
    assert_match /bar/, result.stdout
  end

end
