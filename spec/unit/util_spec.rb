require 'spec_helper'

describe Hiera::Util do
  describe 'Hiera::Util.posix?' do
    it 'should return true on posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      Hiera::Util.posix?.should be_true
    end

    it 'should return false on non posix systems' do
      Etc.expects(:getpwuid).with(0).returns(nil)
      Hiera::Util.posix?.should be_false
    end
  end

  describe 'Hiera::Util.microsoft_windows?' do
    it 'should return false on posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      Hiera::Util.microsoft_windows?.should be_false
    end
  end

  describe 'Hiera::Util.config_dir' do
    it 'should return the correct path for posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      Hiera::Util.config_dir.should == '/etc'
    end
  end

  describe 'Hiera::Util.var_dir' do
    it 'should return the correct path for posix systems' do
      Etc.expects(:getpwuid).with(0).returns(true)
      Hiera::Util.var_dir.should == '/var/lib/hiera'
    end
  end
end

