require 'spec_helper'

class Hiera
  describe Config do
    describe "#load" do
      let(:default_config) do
        {
          :backends  => ["yaml"],
          :hierarchy => ['nodes/%{::trusted.certname}', 'common'],
          :logger    => "console",
          :merge_behavior=>:native
        }
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

        expect(Config.load("/nonexisting")).to eq(default_config)
      end

      it "should use hash data as source if supplied" do
        config = Config.load({"rspec" => "test"})
        expect(config["rspec"]).to eq("test")
      end

      it "should merge defaults with the loaded or supplied config" do
        config = Config.load({})
        expect(config).to eq({:backends => ["yaml"], :hierarchy => ['nodes/%{::trusted.certname}', 'common'],
          :logger => "console", :merge_behavior=>:native})
      end

      it "should force :backends to be a flattened array" do
        expect(Config.load({:backends => [["foo", ["bar"]]]})).to eq({:backends => ["foo", "bar"],
          :hierarchy => ['nodes/%{::trusted.certname}', 'common'], :logger => "console", :merge_behavior=>:native})
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

      describe "if deep_merge can't be loaded" do
        let(:error_message) { "Must have 'deep_merge' gem installed for the configured merge_behavior." }
        before(:each) do
          Config.expects(:require).with("deep_merge").raises(LoadError, "unable to load")
        end

        it "should error if merge_behavior is 'deep'" do
          expect { Config.load(:merge_behavior => :deep) }.to raise_error(Hiera::Error, error_message)
        end

        it "should error if merge_behavior is 'deeper'" do
          expect { Config.load(:merge_behavior => :deeper) }.to raise_error(Hiera::Error, error_message)
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
        expect(Config.include?(:foo)).to eq(false)
        expect(Config.include?(:logger)).to eq(true)
      end
    end
  end
end
