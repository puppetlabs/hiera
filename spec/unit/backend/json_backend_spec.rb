require 'spec_helper'
require 'hiera/backend/json_backend'

class Hiera
  module Backend
    describe Json_backend do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        Hiera::Backend.stubs(:empty_answer).returns(nil)
        @backend = Json_backend.new
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera JSON backend starting")
          Json_backend.new
        end
      end

      describe "#lookup" do
        it "should look for data in all sources" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:json, {}, "one", "json").returns(nil)
          Backend.expects(:datafile).with(:json, {}, "two", "json").returns(nil)

          @backend.lookup("key", {}, nil, :priority)
        end

        it "should retain the data types found in data files" do
          Backend.expects(:datasources).yields("one").times(3)
          Backend.expects(:datafile).with(:json, {}, "one", "json").returns("/nonexisting/one.json").times(3)
          File.expects(:read).with("/nonexisting/one.json").returns('{"stringval":"string",
                                                                      "boolval":true,
                                                                      "numericval":1}').times(3)

          Backend.stubs(:parse_answer).with('string', {}).returns('string')
          Backend.stubs(:parse_answer).with(true, {}).returns(true)
          Backend.stubs(:parse_answer).with(1, {}).returns(1)

          @backend.lookup("stringval", {}, nil, :priority).should == "string"
          @backend.lookup("boolval", {}, nil, :priority).should == true
          @backend.lookup("numericval", {}, nil, :priority).should == 1
        end

        it "should pick data earliest source that has it for priority searches" do
          scope = {"rspec" => "test"}
          Backend.stubs(:parse_answer).with('answer', scope).returns("answer")
          Backend.stubs(:parse_answer).with('test_%{rspec}', scope).returns("test_test")
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:json, scope, "one", "json").returns("/nonexisting/one.json")
          Backend.expects(:datafile).with(:json, scope, "two", "json").returns(nil).never
          File.expects(:read).with("/nonexisting/one.json").returns("one.json")
          JSON.expects(:parse).with("one.json").returns({"key" => "test_%{rspec}"})

          @backend.lookup("key", scope, nil, :priority).should == "test_test"
        end

        it "should build an array of all data sources for array searches" do
          Hiera::Backend.stubs(:empty_answer).returns([])
          Backend.stubs(:parse_answer).with('answer', {}).returns("answer")
          Backend.expects(:datafile).with(:json, {}, "one", "json").returns("/nonexisting/one.json")
          Backend.expects(:datafile).with(:json, {}, "two", "json").returns("/nonexisting/two.json")

          Backend.expects(:datasources).multiple_yields(["one"], ["two"])

          File.expects(:read).with("/nonexisting/one.json").returns("one.json")
          File.expects(:read).with("/nonexisting/two.json").returns("two.json")

          JSON.expects(:parse).with("one.json").returns({"key" => "answer"})
          JSON.expects(:parse).with("two.json").returns({"key" => "answer"})

          @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
        end

        it "should parse the answer for scope variables" do
          Backend.stubs(:parse_answer).with('test_%{rspec}', {'rspec' => 'test'}).returns("test_test")
          Backend.expects(:datasources).yields("one")
          Backend.expects(:datafile).with(:json, {"rspec" => "test"}, "one", "json").returns("/nonexisting/one.json")

          File.expects(:read).with("/nonexisting/one.json").returns("one.json")
          JSON.expects(:parse).with("one.json").returns({"key" => "test_%{rspec}"})

          @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
        end
      end
    end
  end
end
