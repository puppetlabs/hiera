begin test_name "Lookup data using the default options"

step 'Setup'
apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata/global.yaml':
  ensure  => present,
  content => "---
    http_port: 8080
    ntp_servers: ['0.ntp.puppetlabs.com', '1.ntp.puppetlabs.com']
    users:
      pete:
        uid: 2000
        gid: 2000
        shell: '/bin/bash'
      tom:
        uid: 2001
        gid: 2001
        shell: '/bin/bash'
  "
}
PP

step "Try to lookup string data"
on master, hiera("http_port"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> 8080
  OUTPUT
end

step "Try to lookup array data"
on master, hiera("ntp_servers"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    STDOUT> ["0.ntp.puppetlabs.com", "1.ntp.puppetlabs.com"]
  OUTPUT
end

step "Try to lookup hash data"
on master, hiera("users"), :acceptable_exit_codes => [0] do
  assert_output <<-OUTPUT
    {"tom"=>{"gid"=>2001, "uid"=>2001, "shell"=>"/bin/bash"}, "pete"=>{"gid"=>2000, "uid"=>2000, "shell"=>"/bin/bash"}}
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
PP
end
