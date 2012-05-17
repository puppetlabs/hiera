test_name "Lookup data without a key"

step "Try to lookup data without specifying a key"

on master, hiera(""), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDERR> Please supply a data item to look up
  OUTPUT
end
