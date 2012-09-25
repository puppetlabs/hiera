begin test_name "Lookup data with Hash search"

step 'Setup'
apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata/production.yaml':
  ensure  => present,
  content => "---
    users:
      joe:
        uid: 1000
  "
}

file { '/etc/puppet/hieradata/global.yaml':
  ensure  => present,
  content => "---
    users:
      pete:
        uid: 1001
  "
}

file { '/etc/puppet/scope.yaml':
  ensure  => present,
  content => "---
    environment: production
  "
}
PP

step "Try to lookup data using hash search"
on master, hiera('users', '--yaml', '/etc/puppet/scope.yaml', '--hash'),
  :acceptable_exit_codes => [0] do
  assert_match /joe[^}]+"uid"=>1000}/, result.output
  assert_match /pete[^}]+"uid"=>1001}/, result.output
end

ensure step "Teardown"
apply_manifest_on master, <<-PP
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
