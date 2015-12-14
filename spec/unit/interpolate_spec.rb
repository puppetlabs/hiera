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
      end.to raise_error Hiera::InterpolationLoop, 'Lookup recursion detected in [hiera("bar"), hiera("foo")]'
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

  context "when doing interpolation with override" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'override') }

    it 'should resolve interpolation using the override' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('foo', nil, {}, 'alternate')).to eq('alternate')
    end
  end

  context 'when doing interpolation in config file' do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }

    it 'should allow and resolve a correctly configured interpolation using "hiera" method' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera.yaml'))
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end

    it 'should detect interpolation recursion when using "hiera" method' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera_bad.yaml'))
      expect{ hiera.lookup('foo', nil, {}) }.to raise_error(Hiera::InterpolationLoop, "Lookup recursion detected in [hiera('role')]")
    end

    it 'should issue warning when interpolation methods are used' do
      Hiera.expects(:warn).with('Use of interpolation methods in hiera configuration file is deprecated').at_least_once
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera.yaml'))
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end
  end
end
