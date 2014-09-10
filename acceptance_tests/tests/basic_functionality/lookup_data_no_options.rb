test_name "Lookup data with no options"
# this test will break if someone leaves a weird config file lying around...
# but we want to test a default install, so it will remain fragile

step "create common data file"
agents.each do |this_agent|
  if this_agent['platform'] =~ /windows/
    datadir = 'C:/PROGRA~3/PuppetLabs/hiera/var/'
  else
    datadir = '/var/lib/hiera/'
  end

  commonYaml = 'global.yaml'
  data_file = File.join(datadir, commonYaml)

  common_content = <<-HERE
---
foo: bar
  HERE

  on(this_agent, "rm -rf '#{datadir}'")
  on(this_agent, "mkdir  '#{datadir}'")
  create_remote_file(this_agent, data_file, common_content)

  step "lookup data"
  on(this_agent, hiera('foo')) do
    assert_output <<-OUTPUT
      STDOUT> bar
    OUTPUT
  end

  teardown do
    on(this_agent, "rm -rf '#{datadir}'")
  end
end
