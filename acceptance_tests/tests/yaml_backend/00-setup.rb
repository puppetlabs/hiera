test_name "Hiera setup for YAML backend"

apply_manifest_on master, <<-PP
file { '/etc/hiera.yaml':
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
      :datadir: "/etc/puppet/hieradata"
  '
}

file { '/etc/puppet/hieradata':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP
