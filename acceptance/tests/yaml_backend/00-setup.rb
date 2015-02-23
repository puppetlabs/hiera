test_name "Hiera setup for YAML backend"

agents.each do |agent|
  puppetcodedir = agent.puppet()[:codedir]
  hieradatadir = "#{puppetcodedir}/hieradata"
  apply_manifest_on agent, <<-PP
file { '/etc/puppetlabs':
  ensure  => directory,
}->
file { '/etc/puppetlabs/code':
  ensure  => directory,
}->
file { '/etc/puppetlabs/code/hiera.yaml':
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
