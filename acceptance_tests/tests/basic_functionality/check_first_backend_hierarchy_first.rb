test_name "should check first backend hierarchy first"

global_data_yaml = 'global.yaml'
global_data_json = 'global.json'
agents.each do |this_agent|
  if this_agent['platform'] =~ /windows/
    datadir = 'C:/PROGRA~3/PuppetLabs/hiera/var/'
  else
    datadir = '/etc/puppet/hieradata'
  end
  data_file_yaml = File.join(datadir, global_data_yaml)
  data_file_json = File.join(datadir, global_data_json)

  conf_content = <<-CONF
---
  :backends:
    - "json"
    - "yaml"
  :hierarchy:
    - "global"

  :yaml:
    :datadir: "#{datadir}"
  :json:
    :datadir: "#{datadir}"
  CONF

  yaml_data = <<-YAML
---
foo: barYaml
foo2: bar2Yaml
  YAML

  json_data = <<-JSON
{
  "foo": "barJson",
  "foo2": "bar2Json"
}
  JSON

  step "backup config; config with two backends; create two hierarchies"
  confPath = {}
  if this_agent['platform'] =~ /windows/
    confPath = on(this_agent, "echo #{this_agent['hieraconf']}")
    confPath = confPath.raw_output.chomp
  else # hieraconf incorrect for CLI in unix
    confPath = '/etc/hiera.yaml'
  end
  on(this_agent, "if [ -f #{confPath} ]; then cp '#{confPath}' '#{confPath}.bak'; fi")
  create_remote_file(this_agent, confPath, conf_content )
  on(this_agent, "rm -rf '#{datadir}'")
  on(this_agent, "mkdir -p '#{datadir}'")
  create_remote_file(this_agent, data_file_yaml, yaml_data)
  create_remote_file(this_agent, data_file_json, json_data)

  step "lookup data"
  on(this_agent, hiera("-c '#{confPath}' ", 'foo')) do
    assert_output <<-OUTPUT
      STDOUT> barJson
    OUTPUT
  end

  step "swap hierarchy order; and lookup data again"
  conf_content = <<-CONF
---
  :backends:
    - "yaml"
    - "json"
  :logger: "console"
  :hierarchy:
    - "%{fqdn}"
    - "%{environment}"
    - "global"

  :yaml:
    :datadir: "#{datadir}"
  :json:
    :datadir: "#{datadir}"
  CONF

  create_remote_file(this_agent, confPath, conf_content)
  on(this_agent, hiera("-c '#{confPath}' ", 'foo')) do
    assert_output <<-OUTPUT
      STDOUT> barYaml
    OUTPUT
  end

  teardown do
    on(this_agent, "rm -rf '#{datadir}'")
    on(this_agent, "if [ -f #{confPath}.bak ]; then mv '#{confPath}.bak' '#{confPath}'; fi")
  end
end
