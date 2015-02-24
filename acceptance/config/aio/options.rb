{
  :type => 'aio',
  :puppetbindir => '/opt/puppetlabs/puppet/bin',
  :pre_suite => [
    'setup/aio/pre-suite/010_Install.rb',
    'setup/aio/pre-suite/020_AIO_Workarounds.rb',
  ],
}
