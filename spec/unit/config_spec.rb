require File.dirname(__FILE__) + '/../spec_helper'

class Hiera
    describe Config do
        describe "#load" do
            it "should treat string sources as a filename" do
                expect {
                    Config.load("/nonexisting")
                }.to raise_error("Config file /nonexisting not found")
            end

            it "should attempt to YAML load config files" do
                File.expects(:exist?).with("/nonexisting").returns(true)
                YAML.expects(:load_file).with("/nonexisting").returns({})

                Config.load("/nonexisting")
            end

            it "should use hash data as source if supplied" do
                config = Config.load({"rspec" => "test"})
                config["rspec"].should == "test"
            end

            it "should merge defaults with the loaded or supplied config" do
                config = Config.load({})
                config.should == {:backends => ["yaml"], :hierarchy => "common", :logger => "console"}
            end

            it "should force :backends to be a flattened array" do
                Config.load({:backends => [["foo", ["bar"]]]}).should == {:backends => ["foo", "bar"], :hierarchy => "common", :logger => "console"}
            end

            it "should load the supplied logger" do
                Hiera.expects(:logger=).with("foo")
                Config.load({:logger => "foo"})
            end

            it "should default to the console logger" do
                Hiera.expects(:logger=).with("console")
                Config.load({})
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
