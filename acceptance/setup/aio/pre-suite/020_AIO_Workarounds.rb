test_name 'temporary aio workarounds: ensure puppet and friends are on the path'

step 'setup the symbolic links that aio packaging is not yet providing'
puppet_bindir = options[:puppetbindir]
new_puppet_bindir = '/opt/puppetlabs/bin'
agents.each do |agent|
  # stick current puppet hard-path in the ... PATH so we can use configprint
  agent.add_env_var('PATH', "#{puppet_bindir}/puppet:$PATH")
  on(agent, "mkdir #{new_puppet_bindir}")
  on(agent, "ln -s #{puppet_bindir}/puppet " \
            "#{new_puppet_bindir}/puppet")
  on(agent, "ln -s #{puppet_bindir}/hiera " \
            "#{new_puppet_bindir}/hiera")
  on(agent, "ln -s #{puppet_bindir}/facter " \
            "#{new_puppet_bindir}/facter")
  agent.add_env_var('PATH', "#{new_puppet_bindir}:$PATH")
end

# The AIO puppet-agent package does not create the puppet user or group, but
# puppet-server does. However, some puppet acceptance tests assume the user
# is present. This is a temporary setup step to create the puppet user and
# group, but only on nodes that are agents and not the master
step '(PUP-3997) Puppet User and Group on agents only'
agents.each do |agent|
  step "Ensure puppet user and group added to #{agent}" do
    on(agent, puppet('resource user puppet ensure=present'))
    on(agent, puppet('resource group puppet ensure=present'))
  end
end
