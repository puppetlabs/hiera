{
  :install => ['PUPPET/master', 'FACTER/2.x'],
  :pre_suite => [
    'setup/common/00_EnvSetup.rb',
    'setup/git/pre-suite/01_TestSetup.rb',
  ],
}
