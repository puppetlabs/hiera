require 'spec_helper'

describe Hiera::Util do
  describe 'Hiera::Util.posix?' do
    it 'should return true on posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      expect(Hiera::Util.posix?).to be_truthy
    end

    it 'should return false on non posix systems' do
      Etc.expects(:getpwuid).with(0).returns(nil)
      expect(Hiera::Util.posix?).to be_falsey
    end
  end

  describe 'Hiera::Util.microsoft_windows?' do
    it 'should return false on posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      expect(Hiera::Util.microsoft_windows?).to be_falsey
    end
  end

  describe 'Hiera::Util.config_dir' do
    it 'should return the correct path for posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      expect(Hiera::Util.config_dir).to eq('/etc/puppetlabs/puppet')
    end

    it 'should return the correct path for microsoft windows systems' do
      Hiera::Util.expects(:microsoft_windows?).returns(true)
      Hiera::Util.expects(:common_appdata).returns('C:\\ProgramData')
      expect(Hiera::Util.config_dir).to eq('C:\\ProgramData/PuppetLabs/puppet/etc')
    end
  end

  describe 'Hiera::Util.code_dir' do
    it 'should return the correct path for posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      expect(Hiera::Util.code_dir).to eq('/etc/puppetlabs/code')
    end

    it 'should return the correct path for microsoft windows systems' do
      Hiera::Util.expects(:microsoft_windows?).returns(true)
      Hiera::Util.expects(:common_appdata).returns('C:\\ProgramData')
      expect(Hiera::Util.code_dir).to eq('C:\\ProgramData/PuppetLabs/code')
    end
  end

  describe 'Hiera::Util.var_dir' do
    it 'should return the correct path for posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      expect(Hiera::Util.var_dir).to eq('/etc/puppetlabs/code/environments/%{environment}/hieradata')
    end

    it 'should return the correct path for microsoft windows systems' do
      Hiera::Util.expects(:microsoft_windows?).returns(true)
      Hiera::Util.expects(:common_appdata).returns('C:\\ProgramData')
      expect(Hiera::Util.var_dir).to eq('C:\\ProgramData/PuppetLabs/code/environments/%{environment}/hieradata')
    end
  end
end

