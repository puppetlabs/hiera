require 'spec_helper'
require 'hiera/util'

describe "Hiera" do
  describe "#logger=" do
    it "should attempt to load the supplied logger" do
      Hiera.stubs(:warn)
      Hiera.expects(:require).with("hiera/foo_logger").raises("fail")
      Hiera.logger = "foo"
    end

    it "should fall back to the Console logger on failure" do
      Hiera.expects(:warn)
      Hiera.logger = "foo"
      Hiera.logger.should be Hiera::Console_logger
    end
  end

  describe "#warn" do
    it "should call the supplied logger" do
      Hiera::Console_logger.expects(:warn).with("rspec")
      Hiera.warn("rspec")
    end
  end

  describe "#debug" do
    it "should call the supplied logger" do
      Hiera::Console_logger.expects(:debug).with("rspec")
      Hiera.debug("rspec")
    end
  end

  describe "#initialize" do
    it "should use a default config" do
      config_file = File.join(Hiera::Util.config_dir, 'hiera.yaml')
      Hiera::Config.expects(:load).with(config_file)
      Hiera::Config.stubs(:load_backends)
      Hiera.new
    end

    it "should pass the supplied config to the config class" do
      Hiera::Config.expects(:load).with({"test" => "rspec"})
      Hiera::Config.stubs(:load_backends)
      Hiera.new(:config => {"test" => "rspec"})
    end

    it "should load all backends on start" do
      Hiera::Config.stubs(:load)
      Hiera::Config.expects(:load_backends)
      Hiera.new
    end
  end

  describe "#lookup" do
    it "should proxy to the Backend#lookup method" do
      Hiera::Config.stubs(:load)
      Hiera::Config.stubs(:load_backends)
      Hiera::Backend.expects(:lookup).with(:key, :default, :scope, :order_override, :resolution_type)
      Hiera.new.lookup(:key, :default, :scope, :order_override, :resolution_type)
    end
  end
end
