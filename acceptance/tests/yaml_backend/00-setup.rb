test_name "Hiera setup for YAML backend"

agents.each do |agent|
  codedir = agent.puppet['codedir']
  hieradatadir = File.join(codedir, 'hieradata')
  apply_manifest_on agent, <<-PP
file { '#{codedir}/hiera.yaml':
  ensure  => present,
  content => '---
    :backends:
      - "yaml"
    :logger: "console"
    :hierarchy:
      - "%{fqdn}"
      - "%{environment}"
      - "global"

    :yaml:
      :datadir: "#{hieradatadir}"
  '
}

file { '#{hieradatadir}':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP
end
