require 'spec_helper'

class Hiera
  describe Config do
    describe "#load" do
      let(:default_config) do
        {
          :backends  => ["yaml"],
          :hierarchy => "common",
          :logger    => "console",
          :merge_behavior=>:native
        }
      end

      it "should treat string sources as a filename" do
        expect { Config.load("/nonexisting") }.to raise_error
      end

      it "should raise an error for missing config files" do
        File.expects(:exist?).with("/nonexisting").returns(false)
        YAML.expects(:load_file).with("/nonexisting").never

        expect { Config.load("/nonexisting") }.to raise_error "Config file /nonexisting not found"
      end

      it "should attempt to YAML load config files" do
        File.expects(:exist?).with("/nonexisting").returns(true)
        YAML.expects(:load_file).with("/nonexisting").returns(YAML.load("---\n"))

        Config.load("/nonexisting")
      end

      it "should use defaults on empty YAML config file" do
        File.expects(:exist?).with("/nonexisting").returns(true)
        YAML.expects(:load_file).with("/nonexisting").returns(YAML.load(""))

        Config.load("/nonexisting").should == default_config
      end

      it "should use hash data as source if supplied" do
        config = Config.load({"rspec" => "test"})
        config["rspec"].should == "test"
      end

      it "should merge defaults with the loaded or supplied config" do
        config = Config.load({})
        config.should == {:backends => ["yaml"], :hierarchy => "common", :logger => "console", :merge_behavior=>:native}
      end

      it "should force :backends to be a flattened array" do
        Config.load({:backends => [["foo", ["bar"]]]}).should == {:backends => ["foo", "bar"], :hierarchy => "common", :logger => "console", :merge_behavior=>:native}
      end

      it "should load the supplied logger" do
        Hiera.expects(:logger=).with("foo")
        Config.load({:logger => "foo"})
      end

      it "should default to the console logger" do
        Hiera.expects(:logger=).with("console")
        Config.load({})
      end

      context "loading '/dev/null' as spec tests do", :unless => Hiera::Util.microsoft_windows? do
        before :each do
          # Simulate the behavior of YAML.load_file('/dev/null') in MRI 1.9.3p194
          Config.stubs(:yaml_load_file).
            raises(TypeError, "no implicit conversion from nil to integer")
        end

        it "is not exceptional behavior" do
          Config.load('/dev/null')
        end
      end
    end

    describe "#load_backends" do
      it "should load each backend" do
        Config.load(:backends => ["One", "Two"])
        Config.expects(:require).with("hiera/backend/one_backend")
        Config.expects(:require).with("hiera/backend/two_backend")
        Config.load_backends
      end

      it "should warn if it cant load a backend" do
        Config.load(:backends => ["one"])
        Config.expects(:require).with("hiera/backend/one_backend").raises("fail")

        expect {
            Config.load_backends
        }.to raise_error("fail")
      end
    end

    describe "#include?" do
      it "should correctly report inclusion" do
        Config.load({})
        Config.include?(:foo).should == false
        Config.include?(:logger).should == true
      end
    end
  end
end
