test_name "Hiera setup for YAML backend"

agents.each do |agent|
  apply_manifest_on agent, <<-PP
file { '#{agent['hieraconf']}':
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
