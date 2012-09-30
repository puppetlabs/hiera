require 'spec_helper'

class Hiera
  describe Filecache do
    before do
      File.stubs(:exist?).returns(true)
      @cache = Filecache.new
    end

    describe "#read" do
      it "should cache and read data" do
        File.expects(:read).with("/nonexisting").returns("text")
        @cache.expects(:path_metadata).returns(File.stat(__FILE__)).once
        @cache.expects(:stale?).once.returns(false)

        @cache.read("/nonexisting").should == "text"
        @cache.read("/nonexisting").should == "text"
      end

      it "should support validating return types and setting defaults" do
        File.expects(:read).with("/nonexisting").returns('{"rspec":1}')

        @cache.expects(:path_metadata).returns(File.stat(__FILE__))

        Hiera.expects(:debug).with(regexp_matches(/is not a Hash, setting defaults/))

        # return bogus data on purpose, triggers setting defaults
        data = @cache.read("/nonexisting", Hash, {"rspec" => 1}) do |data|
          nil
        end

        data.should == {"rspec" => 1}
      end
    end

    describe "#stale?" do
      it "should return false when the file has not changed" do
        stat = File.stat(__FILE__)

        @cache.stubs(:path_metadata).returns(stat)
        @cache.stale?("/nonexisting").should == true
        @cache.stale?("/nonexisting").should == false
      end

      it "should update and return true when the file changed" do
        @cache.expects(:path_metadata).returns({:inode => 1, :mtime => Time.now, :size => 1})
        @cache.stale?("/nonexisting").should == true
        @cache.expects(:path_metadata).returns({:inode => 2, :mtime => Time.now, :size => 1})
        @cache.stale?("/nonexisting").should == true
      end
    end

    describe "#path_metadata" do
      it "should return the right data" do
        stat = File.stat(__FILE__)

        File.expects(:stat).with("/nonexisting").returns(stat)

        @cache.path_metadata("/nonexisting").should == {:inode => stat.ino, :mtime => stat.mtime, :size => stat.size}
      end
    end
  end
end
