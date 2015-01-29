test_name "Hiera setup for YAML backend"

agents.each do |agent|
  apply_manifest_on agent, <<-PP
file { '/etc/puppetlabs':
  ensure  => directory,
}->
file { '/etc/puppetlabs/agent':
  ensure  => directory,
}->
file { '/etc/puppetlabs/agent/code':
  ensure  => directory,
}->
file { '/etc/puppetlabs/agent/code/hiera.yaml':
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
      :datadir: "#{agent['hieradatadir']}"
  '
}

file { '#{agent['hieradatadir']}':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP
end
