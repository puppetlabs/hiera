require 'spec_helper'
require 'hiera/util'

# This is only around for the logger setup tests
module Hiera::Foo_logger
end

describe "Hiera" do
  describe "#logger=" do
    it "loads the given logger" do
      Hiera.expects(:require).with("hiera/foo_logger")

      Hiera.logger = "foo"
    end

    it "falls back to the Console logger when the logger could not be loaded" do
      Hiera.expects(:warn)

      Hiera.logger = "no_such_logger"

      expect(Hiera.logger).to be Hiera::Console_logger
    end

    it "falls back to the Console logger when the logger class could not be found" do
      Hiera.expects(:warn)
      Hiera.expects(:require).with("hiera/no_constant_logger")

      Hiera.logger = "no_constant"

      expect(Hiera.logger).to be Hiera::Console_logger
    end
  end

  describe "#warn" do
    it "delegates to the configured logger" do
      Hiera.logger = 'console'
      Hiera::Console_logger.expects(:warn).with("rspec")

      Hiera.warn("rspec")
    end
  end

  describe "#debug" do
    it "delegates to the configured logger" do
      Hiera.logger = 'console'
      Hiera::Console_logger.expects(:debug).with("rspec")

      Hiera.debug("rspec")
    end
  end

  describe "#initialize" do
    it "uses a default config file when none is provided" do
      config_file = File.join(Hiera::Util.config_dir, 'hiera.yaml')
      Hiera::Config.expects(:load).with(config_file)
      Hiera::Config.stubs(:load_backends)
      Hiera.new
    end

    it "passes the supplied config to the config class" do
      Hiera::Config.expects(:load).with({"test" => "rspec"})
      Hiera::Config.stubs(:load_backends)
      Hiera.new(:config => {"test" => "rspec"})
    end

    it "loads all backends on start" do
      Hiera::Config.stubs(:load)
      Hiera::Config.expects(:load_backends)
      Hiera.new
    end
  end

  describe "#lookup" do
    it "delegates to the Backend#lookup method" do
      Hiera::Config.stubs(:load)
      Hiera::Config.stubs(:load_backends)
      Hiera::Backend.expects(:lookup).with(:key, :default, :scope, :order_override, :resolution_type)
      Hiera.new.lookup(:key, :default, :scope, :order_override, :resolution_type)
    end
  end
end
