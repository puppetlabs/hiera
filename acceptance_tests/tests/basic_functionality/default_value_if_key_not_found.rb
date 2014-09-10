test_name "use the default value if key not found"

step "lookup data with default"
agents.each do |this_agent|
  on(this_agent, hiera('foo', 'bar42')) do
    assert_output <<-OUTPUT
      STDOUT> bar42
    OUTPUT
  end
end
