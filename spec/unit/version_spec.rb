require "spec_helper"
require "hiera/version"
require 'pathname'

describe "Hiera.version Public API" do
  subject() { Hiera }

  before :each do
    Hiera.instance_eval do
      if @hiera_version
        @hiera_version = nil
      end
    end
  end

  context "without a VERSION file" do
    before :each do
      subject.stubs(:read_version_file).returns(nil)
    end

    it "is Hiera::VERSION" do
      subject.version.should == Hiera::VERSION
    end
    it "respects the version= setter" do
      subject.version = '1.2.3'
      subject.version.should == '1.2.3'
    end
  end

  context "with a VERSION file" do
    it "is the content of the file" do
      subject.expects(:read_version_file).with() do |path|
        pathname = Pathname.new(path)
        pathname.basename.to_s == "VERSION"
      end.returns('1.2.1-9-g9fda440')

      subject.version.should == '1.2.1-9-g9fda440'
    end
    it "respects the version= setter" do
      subject.version = '1.2.3'
      subject.version.should == '1.2.3'
    end
  end
end
