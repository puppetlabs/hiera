begin test_name "Lookup data with Hash search"

step 'Setup'
apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata/production.yaml':
  ensure  => present,
  content => "---
    users:
      joe:
        gid: 1000
        uid: 1000
        home: '/home/joe'
  "
}

file { '/etc/puppet/hieradata/global.yaml':
  ensure  => present,
  content => "---
    users:
      pete:
        gid: 1001
        uid: 1001
        home: '/home/pete'
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
  assert_output <<-OUTPUT
    STDOUT> {"joe"=>{"gid"=>1000, "uid"=>1000, "home"=>"/home/joe"}, "pete"=>{"gid"=>1001, "uid"=>1001, "home\"=>"/home/pete"}}
  OUTPUT
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
