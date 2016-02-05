require 'spec_helper'
require 'hiera/util'

describe "Hiera" do
  context "when doing interpolation" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }

    it 'should prevent endless recursion' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect do
        hiera.lookup('foo', nil, {})
      end.to raise_error Hiera::InterpolationLoop, 'Detected in [hiera("bar"), hiera("foo")]'
    end
  end

  context "when not finding value for interpolated key" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }

    it 'should resolve the interpolation to an empty string' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('niltest', nil, {})).to eq('Missing key ##. Key with nil ##')
    end
  end

  context "when there are empty interpolations %{} in data" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }

    it 'should should produce an empty string for the interpolation' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('empty_interpolation', nil, {})).to eq('clownshoe')
    end

    it 'the empty interpolation can be escaped' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('escaped_empty_interpolation', nil, {})).to eq('clown%{shoe}s')
    end

    it 'the value can consist of only an empty escape' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('only_empty_interpolation', nil, {})).to eq('')
    end

    it 'the value can consist of an empty namespace %{::}' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('empty_namespace', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{ :: }' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('whitespace1', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{  }' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('whitespace2', nil, {})).to eq('')
    end
  end

  context "when doing interpolation with override" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'override') }

    it 'should resolve interpolation using the override' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('foo', nil, {}, 'alternate')).to eq('alternate')
    end
  end
end
