require 'spec_helper'

describe Hiera::Util do
  describe 'Hiera::Util.posix?' do
    it 'should return true on posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      Hiera::Util.posix?.should be_truthy
    end

    it 'should return false on non posix systems' do
      Etc.expects(:getpwuid).with(0).returns(nil)
      Hiera::Util.posix?.should be_falsey
    end
  end

  describe 'Hiera::Util.microsoft_windows?' do
    it 'should return false on posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      Hiera::Util.microsoft_windows?.should be_falsey
    end
  end

  describe 'Hiera::Util.config_dir' do
    it 'should return the correct path for posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      Hiera::Util.config_dir.should == '/etc/puppetlabs/code'
    end

    it 'should return the correct path for microsoft windows systems' do
      Hiera::Util.expects(:microsoft_windows?).returns(true)
      Hiera::Util.expects(:common_appdata).returns('C:\\ProgramData')
      Hiera::Util.config_dir.should == 'C:\\ProgramData/PuppetLabs/code'
    end
  end

  describe 'Hiera::Util.var_dir' do
    it 'should return the correct path for posix systems' do
      Hiera::Util.expects(:file_alt_separator).returns(nil)
      Hiera::Util.var_dir.should == '/etc/puppetlabs/code/environments/%{environment}/hieradata'
    end

    it 'should return the correct path for microsoft windows systems' do
      Hiera::Util.expects(:microsoft_windows?).returns(true)
      Hiera::Util.expects(:common_appdata).returns('C:\\ProgramData')
      Hiera::Util.var_dir.should == 'C:\\ProgramData/PuppetLabs/code/environments/%{environment}/hieradata'
    end
  end
end

