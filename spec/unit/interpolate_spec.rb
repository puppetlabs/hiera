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

    it 'should not permit interpolation method "hiera"' do
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera.yaml'))
      expect{ hiera.lookup('foo', nil, {}) }.to raise_error(Hiera::InterpolationInvalidValue, "Cannot use interpolation method 'hiera' in hiera configuration file")
    end

    it 'should issue warning when interpolation methods are used' do
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_other.yaml'))
      Hiera.expects(:warn).with('Use of interpolation methods in hiera configuration file is deprecated').at_least_once
      hiera.lookup('foo', nil, {})
    end
  end
end
