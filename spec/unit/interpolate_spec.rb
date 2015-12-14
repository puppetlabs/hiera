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
end
