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
