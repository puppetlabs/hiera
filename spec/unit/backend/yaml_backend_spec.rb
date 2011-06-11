require File.dirname(__FILE__) + '/../../spec_helper'

require 'hiera/backend/yaml_backend'

class Hiera
    module Backend
        describe Yaml_backend do
            before do
                Hiera.stubs(:debug)
                Hiera.stubs(:warn)
                @backend = Yaml_backend.new
            end

            describe "#initialize" do
                it "should announce its creation" do # because other specs checks this
                    Hiera.expects(:debug).with("Hiera YAML backend starting")
                    Yaml_backend.new
                end
            end

            describe "#lookup" do
                it "should look for data in all sources" do
                    Backend.expects(:datadir).returns("/nonexisting").twice
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(false)
                    File.expects(:exist?).with("/nonexisting/two.yaml").returns(false)

                    @backend.lookup("key", {}, nil, :priority)
                end

                it "should pick data earliest source that has it for priority searches" do
                    Backend.expects(:datadir).returns("/nonexisting")
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(true)
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "answer"})

                    File.expects(:exist?).with("/nonexisting/two.yaml").never

                    @backend.lookup("key", {}, nil, :priority).should == "answer"
                end

                it "should build an array of all data sources for array searches" do
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "answer"})
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => "answer"})

                    @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
                end

                it "should parse the answer for scope variables" do
                    Backend.expects(:datadir).returns("/nonexisting")
                    Backend.expects(:datasources).yields("one")
                    File.expects(:exist?).with("/nonexisting/one.yaml").returns(true)
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "test_%{rspec}"})

                    @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
                end
            end
        end
    end
end
