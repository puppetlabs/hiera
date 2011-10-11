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
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns(nil)
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns(nil)

                    @backend.lookup("key", {}, nil, :priority)
                end

                it "should pick data earliest source that has it for priority searches" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns(nil).never
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "answer"})

                    @backend.lookup("key", {}, nil, :priority).should == "answer"
                end

                it "should build an array of all data sources for array searches" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "answer"})
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => "answer"})

                    @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
                end

                it "should return empty hash of data sources for hash searches" do
                    Backend.expects(:datasources).multiple_yields(["one"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns("")

                    @backend.lookup("key", {}, nil, :hash).should == {}
                end

                it "should ignore empty hash of data sources for hash searches" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns("")
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => {"a"=>"answer"}})

                    @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer"}
                end

                it "should build a merged hash of data sources for hash searches" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => {"a" => "answer"}})
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => {"a" => "wrong", "b"=>"answer"}})

                    @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer", "b" => "answer"}
                end

                it "should fail when trying to << a Hash" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => ["a", "answer"]})
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => {"a" => "wrong"}})

                    lambda {@backend.lookup("key", {}, nil, :array)}.should raise_error(Exception, "Hiera type mismatch: expected Array and got Hash")
                end

                it "should fail when trying to merge an Array" do
                    Backend.expects(:datasources).multiple_yields(["one"], ["two"])
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
                    Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => {"a" => "answer"}})
                    YAML.expects(:load_file).with("/nonexisting/two.yaml").returns({"key" => ["a", "wrong"]})

                    lambda {@backend.lookup("key", {}, nil, :hash)}.should raise_error(Exception, "Hiera type mismatch: expected Hash and got Array")
                end

                it "should parse the answer for scope variables" do
                    Backend.expects(:datasources).yields("one")
                    Backend.expects(:datafile).with(:yaml, {"rspec" => "test"}, "one", "yaml").returns("/nonexisting/one.yaml")
                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"key" => "test_%{rspec}"})

                    @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
                end

                it "should retain datatypes found in yaml files" do
                    Backend.expects(:datasources).yields("one").times(3)
                    Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml").times(3)

                    YAML.expects(:load_file).with("/nonexisting/one.yaml").returns({"stringval" => "string", "boolval" => true, "numericval" => 1}).times(3)

                    @backend.lookup("stringval", {}, nil, :priority).should == "string"
                    @backend.lookup("boolval", {}, nil, :priority).should == true
                    @backend.lookup("numericval", {}, nil, :priority).should == 1
                end
            end
        end
    end
end
