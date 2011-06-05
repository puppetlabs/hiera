require File.dirname(__FILE__) + '/../../spec_helper'

require 'hiera/backend/yaml_backend'

class Hiera
    module Backend
        describe Yaml_backend do
            describe "#initialize" do
                it "should announce its creation" do # because other specs checks this
                    Hiera.expects(:debug).with("Hiera YAML backend starting")
                    Yaml_backend.new
                end
            end

            describe "#lookup" do
                before do
                    Hiera.stubs(:debug)
                    Hiera.stubs(:warn)
                    @backend = Yaml_backend.new
                end

                it "should fail for missing datadir" do
                    Backend.expects(:datadir).with(:yaml, {}).returns("/nonexisting")

                    expect {
                        @backend.lookup("key", {}, nil, nil)
                    }.to raise_error("Cannot find data directory /nonexisting")
                end

                it "should look for data in all sources" do
                    Backend.expects(:datadir).with(:yaml, {}).returns("/nonexisting")
                    File.expects(:directory?).with("/nonexisting").returns(true)
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(false)
                    File.expects(:exist?).with("/nonexisting/two.yaml").returns(false)
                    @backend.lookup("key", {}, nil, nil)
                end

                it "should pick data earliest source that has it" do
                    Backend.expects(:datadir).with(:yaml, {}).returns("/nonexisting")
                    File.expects(:directory?).with("/nonexisting").returns(true)
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(true)
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "answer"})

                    File.expects(:exist?).with("/nonexisting/two.yaml").never

                    @backend.lookup("key", {}, nil, nil).should == "answer"
                end

                it "should parse the answer for scope variables" do
                    Backend.expects(:datadir).with(:yaml, {"rspec" => "test"}).returns("/nonexisting")
                    File.expects(:directory?).with("/nonexisting").returns(true)
                    Backend.expects(:datasources).yields("one")
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(true)
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "test_%{rspec}"})

                    @backend.lookup("key", {"rspec" => "test"}, nil, nil).should == "test_test"
                end
            end
        end
    end
end
