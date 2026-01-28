require 'spec_helper'
require 'hiera/util'

describe "Hiera" do
  let!(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }
  let!(:fixture_data) { File.join(fixtures, 'data') }
  let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml')) }

  before(:each) do
    Hiera::Util.expects(:var_dir).at_most(3).returns(fixture_data)
  end

  context "when doing interpolation" do
    it 'should prevent endless recursion' do
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect do
        hiera.lookup('foo', nil, {})
      end.to raise_error Hiera::InterpolationLoop, 'Lookup recursion detected in [hiera("bar"), hiera("foo")]'
    end

    it 'produces a nested hash with arrays from nested aliases with hashes and arrays' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('root', nil, {}, nil, :hash)).to eq({'a'=>{'aa'=>{'b'=>{'bb'=>['text']}}}})
    end

    it 'allows keys with white space' do
      expect(hiera.lookup('ws_key', nil, {})).to eq('value for a ws key')
    end

    it 'allows keys with non alphanumeric characters' do
      expect(hiera.lookup('angry', nil, {})).to eq('not happy')
    end

    it 'supports substring interpolation with literal arguments' do
      expect(hiera.lookup('substring_literal', nil, {})).to eq('cde')
    end

    it 'supports substring interpolation to end of string' do
      expect(hiera.lookup('substring_literal_to_end', nil, {})).to eq('cdef')
    end

    it 'supports substring interpolation with scope arguments' do
      expect(hiera.lookup('substring_scope', nil, {'str' => 'abcdef', 'start' => 1, 'count' => 2})).to eq('bc')
    end

    it 'supports match interpolation with regex literals' do
      expect(hiera.lookup('match_regex_true', nil, {})).to eq('true')
      expect(hiera.lookup('match_regex_false', nil, {})).to eq('false')
    end

    it 'supports match interpolation with regex parentheses and flags' do
      expect(hiera.lookup('match_regex_parens', nil, {})).to eq('true')
      expect(hiera.lookup('match_regex_flags', nil, {})).to eq('true')
    end

    it 'supports match interpolation with escaped slash in regex' do
      expect(hiera.lookup('match_regex_escaped_slash', nil, {})).to eq('true')
    end

    it 'supports match interpolation with plain string matching' do
      expect(hiera.lookup('match_string_true', nil, {})).to eq('true')
      expect(hiera.lookup('match_string_false', nil, {})).to eq('false')
    end

    it 'supports grep_captures interpolation with explicit separator' do
      expect(hiera.lookup('grep_captures_simple', nil, {})).to eq('abc-123-def')
    end

    it 'supports grep_captures interpolation with custom separator (all groups)' do
      expect(hiera.lookup('grep_captures_with_sep', nil, {})).to eq('abc_123_def')
    end

    it 'supports grep_captures interpolation with specific capture groups' do
      expect(hiera.lookup('grep_captures_with_groups', nil, {})).to eq('abc_def')
    end

    it 'supports grep_captures interpolation with all capture groups' do
      expect(hiera.lookup('grep_captures_all_groups', nil, {})).to eq('abc-123-def')
    end

    it 'returns empty string when grep_captures does not match' do
      expect(hiera.lookup('grep_captures_no_match', nil, {})).to eq('')
    end

    it 'supports grep_captures with complex version-like pattern' do
      expect(hiera.lookup('grep_captures_version', nil, {})).to eq('12345_widget_prod')
    end

    it 'supports grep_captures with empty separator to merge captures directly' do
      expect(hiera.lookup('grep_captures_empty_sep', nil, {})).to eq('abc123')
    end

    it 'supports grep_captures with quoted regex pattern' do
      expect(hiera.lookup('grep_captures_quoted_regex', nil, {})).to eq('abc_123')
    end

    it 'supports match with quoted regex pattern' do
      expect(hiera.lookup('match_quoted_regex', nil, {})).to eq('true')
    end

    it 'supports grep_captures with curly brace quantifier in quoted regex' do
      expect(hiera.lookup('grep_captures_curly_quantifier', nil, {})).to eq('12345_widget')
    end

    it 'supports version_gt returning true when first version is greater' do
      expect(hiera.lookup('version_gt_true', nil, {})).to eq('true')
    end

    it 'supports version_gt returning false when first version is less' do
      expect(hiera.lookup('version_gt_false', nil, {})).to eq('false')
    end

    it 'supports version_gt returning false when versions are equal' do
      expect(hiera.lookup('version_gt_equal', nil, {})).to eq('false')
    end

    it 'supports version_gte returning true when first version is greater' do
      expect(hiera.lookup('version_gte_true', nil, {})).to eq('true')
    end

    it 'supports version_gte returning true when versions are equal' do
      expect(hiera.lookup('version_gte_equal', nil, {})).to eq('true')
    end

    it 'supports version_gte returning false when first version is less' do
      expect(hiera.lookup('version_gte_false', nil, {})).to eq('false')
    end

    it 'supports version_lt returning true when first version is less' do
      expect(hiera.lookup('version_lt_true', nil, {})).to eq('true')
    end

    it 'supports version_lt returning false when first version is greater' do
      expect(hiera.lookup('version_lt_false', nil, {})).to eq('false')
    end

    it 'supports version_lt returning false when versions are equal' do
      expect(hiera.lookup('version_lt_equal', nil, {})).to eq('false')
    end

    it 'supports version_lte returning true when first version is less' do
      expect(hiera.lookup('version_lte_true', nil, {})).to eq('true')
    end

    it 'supports version_lte returning true when versions are equal' do
      expect(hiera.lookup('version_lte_equal', nil, {})).to eq('true')
    end

    it 'supports version_lte returning false when first version is greater' do
      expect(hiera.lookup('version_lte_false', nil, {})).to eq('false')
    end

    it 'handles semantic versioning correctly (1.10.0 > 1.9.0)' do
      expect(hiera.lookup('version_semver', nil, {})).to eq('true')
    end

    it 'handles prerelease versions correctly (1.0.0.alpha < 1.0.0)' do
      expect(hiera.lookup('version_prerelease', nil, {})).to eq('true')
    end

    it 'supports grep_captures with 5 groups and selected groups (no separator)' do
      expect(hiera.lookup('grep_captures_5groups_selected', nil, {})).to eq('abcd123@#$')
    end

    it 'supports grep_captures with 5 groups and underscore separator' do
      expect(hiera.lookup('grep_captures_5groups_underscore', nil, {})).to eq('abcd_123_@#$')
    end

    it 'supports grep_captures with 5 groups and explicit empty separator' do
      expect(hiera.lookup('grep_captures_5groups_empty', nil, {})).to eq('abcd123@#$')
    end

    it 'supports grep_captures with 5 groups returning all groups concatenated' do
      expect(hiera.lookup('grep_captures_5groups_all', nil, {})).to eq('abcd123ABC@#$456')
    end

    it 'supports grep_captures with 5 groups and separator only (all groups)' do
      expect(hiera.lookup('grep_captures_5groups_sep_only', nil, {})).to eq('abcd-123-ABC-@#$-456')
    end
  end

  context "when not finding value for interpolated key" do
    it 'should resolve the interpolation to an empty string' do
      expect(hiera.lookup('niltest', nil, {})).to eq('Missing key ##. Key with nil ##')
    end
  end

  context "when there are empty interpolations %{} in data" do
    it 'should should produce an empty string for the interpolation' do
      expect(hiera.lookup('empty_interpolation', nil, {})).to eq('clownshoe')
    end

    it 'the empty interpolation can be escaped' do
      expect(hiera.lookup('escaped_empty_interpolation', nil, {})).to eq('clown%{shoe}s')
    end

    it 'the value can consist of only an empty escape' do
      expect(hiera.lookup('only_empty_interpolation', nil, {})).to eq('')
    end

    it 'the value can consist of an empty namespace %{::}' do
      expect(hiera.lookup('empty_namespace', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{ :: }' do
      expect(hiera.lookup('whitespace1', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{  }' do
      expect(hiera.lookup('whitespace2', nil, {})).to eq('')
    end
  end

  context 'when there are quoted empty interpolations %{} in data' do
    it 'should should produce an empty string for the interpolation' do
      expect(hiera.lookup('quoted_empty_interpolation', nil, {})).to eq('clownshoe')
    end

    it 'the empty interpolation can be escaped' do
      expect(hiera.lookup('quoted_escaped_empty_interpolation', nil, {})).to eq('clown%{shoe}s')
    end

    it 'the value can consist of only an empty escape' do
      expect(hiera.lookup('quoted_only_empty_interpolation', nil, {})).to eq('')
    end

    it 'the value can consist of an empty namespace %{::}' do
      expect(hiera.lookup('quoted_empty_namespace', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{ :: }' do
      expect(hiera.lookup('quoted_whitespace1', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{  }' do
      expect(hiera.lookup('quoted_whitespace2', nil, {})).to eq('')
    end
  end

  context 'when using dotted keys' do
    it 'should find an entry using a quoted interpolation' do
      expect(hiera.lookup('"a.c.scope"', nil, {'a.b' => '(scope) a dot b'})).to eq('a dot c: (scope) a dot b')
    end

    it 'should find an entry using a quoted interpolation with method hiera' do
      expect(hiera.lookup('"a.c.hiera"', nil, {'a.b' => '(scope) a dot b'})).to eq('a dot c: (hiera) a dot b')
    end

    it 'should find an entry using a quoted interpolation with method alias' do
      expect(hiera.lookup('"a.c.alias"', nil, {'a.b' => '(scope) a dot b'})).to eq('(hiera) a dot b')
    end

    it 'should use a dotted key to navigate into a structure when it is not quoted' do
      expect(hiera.lookup('"a.e.scope"', nil, {'a' => { 'd' => '(scope) a dot d is a hash entry'}})).to eq('a dot e: (scope) a dot d is a hash entry')
    end

    it 'should use a dotted key to navigate into a structure when when it is not quoted with method hiera' do
      expect(hiera.lookup('"a.e.hiera"', nil, {'a' => { 'd' => '(scope) a dot d is a hash entry'}})).to eq('a dot e: (hiera) a dot d is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is last' do
      expect(hiera.lookup('"a.ex.scope"', nil, {'a' => { 'd.x' => '(scope) a dot d.x is a hash entry'}})).to eq('a dot ex: (scope) a dot d.x is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is last and method is hiera' do
      expect(hiera.lookup('"a.ex.hiera"', nil, {'a' => { 'd.x' => '(scope) a dot d.x is a hash entry'}})).to eq('a dot ex: (hiera) a dot d.x is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is first' do
      expect(hiera.lookup('"a.xe.scope"', nil, {'a.x' => { 'd' => '(scope) a.x dot d is a hash entry'}})).to eq('a dot xe: (scope) a.x dot d is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is first and method is hiera' do
      expect(hiera.lookup('"a.xe.hiera"', nil, {'a.x' => { 'd' => '(scope) a.x dot d is a hash entry'}})).to eq('a dot xe: (hiera) a.x dot d is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is in the middle' do
      expect(hiera.lookup('"a.xm.scope"', nil, {'a' => { 'd.z' => { 'g' => '(scope) a dot d.z dot g is a hash entry'}}})).to eq('a dot xm: (scope) a dot d.z dot g is a hash entry')
    end

    it 'should use a mix of quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is in the middle and method is hiera' do
      expect(hiera.lookup('"a.xm.hiera"', nil, {'a' => { 'd.z' => { 'g' => '(scope) a dot d.z dot g is a hash entry'}}})).to eq('a dot xm: (hiera) a dot d.z dot g is a hash entry')
    end

    it 'should use a mix of several quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is in the middle' do
      expect(hiera.lookup('"a.xx.scope"', nil, {'a.x' => { 'd.z' => { 'g' => '(scope) a.x dot d.z dot g is a hash entry'}}})).to eq('a dot xx: (scope) a.x dot d.z dot g is a hash entry')
    end

    it 'should use a mix of several quoted and dotted keys to navigate into a structure containing dotted keys and quoted key is in the middle and method is hiera' do
      expect(hiera.lookup('"a.xx.hiera"', nil, {'a.x' => { 'd.z' => { 'g' => '(scope) a.x dot d.z dot g is a hash entry'}}})).to eq('a dot xx: (hiera) a.x dot d.z dot g is a hash entry')
    end

    it 'should find an entry using using a quoted interpolation on dotted key containing numbers' do
      expect(hiera.lookup('"x.2.scope"', nil, {'x.1' => '(scope) x dot 1'})).to eq('x dot 2: (scope) x dot 1')
    end

    it 'should find an entry using using a quoted interpolation on dotted key containing numbers using method hiera' do
      expect(hiera.lookup('"x.2.hiera"', nil, {'x.1' => '(scope) x dot 1'})).to eq('x dot 2: (hiera) x dot 1')
    end

    it 'will allow strange characters in the key' do
      expect(hiera.lookup('very_angry', nil, {})).to eq('not happy at all')
    end

    it 'should not find a subkey when the dotted key is quoted' do
      expect(hiera.lookup('"a.f.scope"', nil, {'a' => { 'f' => '(scope) a dot f is a hash entry'}})).to eq('a dot f: ')
    end

    it 'should not find a subkey when the dotted key is quoted with method hiera' do
      expect(hiera.lookup('"a.f.hiera"', nil, {'a' => { 'f' => '(scope) a dot f is a hash entry'}})).to eq('a dot f: ')
    end

    it 'should not find a subkey that is matched within a string' do
      expect{ hiera.lookup('ipl_key', nil, {}) }.to raise_error(/Got String when a hash-like object was expected to access value using 'subkey' from key 'key.subkey'/)
    end

    it 'should not find a subkey that is matched within a string' do
      expect{ hiera.lookup('key.subkey', nil, {}) }.to raise_error(/Got String when a hash-like object was expected to access value using 'subkey' from key 'key.subkey'/)
    end
  end

  context 'when bad interpolation expressions are encountered' do
    it 'should produce an error when different quotes are used on either side' do
      expect { hiera.lookup('quote_mismatch', nil, {}) }.to raise_error(/Syntax error in interpolation expression: \%\{'the\.key"\}/)
    end

    it 'should produce an if there is only one quote' do
      expect { hiera.lookup('one_quote', nil, {}) }.to raise_error(/Syntax error in interpolation expression: \%\{the\.'key\}/)
    end

    it 'should produce an error for an empty segment' do
      expect { hiera.lookup('empty_segment', nil, {}) }.to raise_error(/Syntax error in interpolation expression: \%\{the\.\.key\}/)
    end

    it 'should produce an error for an empty quoted segment' do
      expect { hiera.lookup('empty_quoted_segment', nil, {}) }.to raise_error(/Syntax error in interpolation expression: \%\{the\.''\.key\}/)
    end

    it 'should produce an error for an partly quoted segment' do
      expect { hiera.lookup('partly_quoted_segment', nil, {}) }.to raise_error(/Syntax error in interpolation expression: \%\{the\.'pa'key\}/)
    end

    it 'should produce an error when different quotes are used on either side in a method argument' do
      expect { hiera.lookup('quote_mismatch_arg', nil, {}) }.to raise_error(/Argument to interpolation method 'hiera' must be quoted, got ''the.key"'/)
    end

    it 'should produce an error unless a known interpolation method is used' do
      expect { hiera.lookup('non_existing_method', nil, {}) }.to raise_error(/Invalid interpolation method 'flubber'/)
    end

    it 'should produce an error if there is only one quote' do
      expect { hiera.lookup('one_quote', nil, {}) }.to raise_error(/Syntax error/)
    end

    it 'should produce an error when different quotes are used on either side in a top-level key' do
      expect { hiera.lookup("'the.key\"", nil, {}) }.to raise_error(/Syntax error in key: 'the.key"/)
    end
  end

  context 'when doing interpolation with override' do
    let!(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'override') }

    it 'should resolve interpolation using the override' do
      expect(hiera.lookup('foo', nil, {}, 'alternate')).to eq('alternate')
    end
  end

  context 'when doing interpolation in config file' do
    let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera.yaml')) }

    it 'should allow and resolve a correctly configured interpolation using "hiera" method' do
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end

    it 'should issue warning when interpolation methods are used' do
      Hiera.expects(:warn).with('Use of interpolation methods in hiera configuration file is deprecated').at_least_once
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end
  end

  context 'when doing interpolation in bad config file' do
    let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera_bad.yaml')) }

    it 'should detect interpolation recursion when using "hiera" method' do
      expect{ hiera.lookup('foo', nil, {}) }.to raise_error(Hiera::InterpolationLoop, "Lookup recursion detected in [hiera('role')]")
    end
  end
end
