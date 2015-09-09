require 'spec_helper'
require 'hiera/backend/json_backend'

class Hiera
  module Backend
    describe Json_backend do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        Hiera::Backend.stubs(:empty_answer).returns(nil)
        @cache = mock
        @backend = Json_backend.new(@cache)
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

          expect { @backend.lookup("key", {}, nil, :priority, nil) }.to throw_symbol(:no_such_key)
        end

        it "should retain the data types found in data files" do
          Backend.expects(:datasources).yields("one").times(3)
          Backend.expects(:datafile).with(:json, {}, "one", "json").returns("/nonexisting/one.json").times(3)
          File.stubs(:exist?).with("/nonexisting/one.json").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.json", Hash).returns({"stringval" => "string", "boolval" => true, "numericval" => 1}).times(3)

          expect(@backend.lookup("stringval", {}, nil, :priority, nil)).to eq("string")
          expect(@backend.lookup("boolval", {}, nil, :priority, nil)).to eq(true)
          expect(@backend.lookup("numericval", {}, nil, :priority, nil)).to eq(1)
        end

        it "should pick data earliest source that has it for priority searches" do
          scope = {"rspec" => "test"}
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:json, scope, "one", "json").returns("/nonexisting/one.json")
          Backend.expects(:datafile).with(:json, scope, "two", "json").never

          File.stubs(:exist?).with("/nonexisting/one.json").returns(true)
          @cache.expects(:read_file).with("/nonexisting/one.json", Hash).returns({"key" => "test_%{rspec}"})

          expect(@backend.lookup("key", scope, nil, :priority, nil)).to eq("test_test")
        end

        it "should build an array of all data sources for array searches" do
          Hiera::Backend.stubs(:empty_answer).returns([])
          Backend.stubs(:parse_answer).with('answer', {}, {}, anything).returns("answer")
          Backend.expects(:datafile).with(:json, {}, "one", "json").returns("/nonexisting/one.json")
          Backend.expects(:datafile).with(:json, {}, "two", "json").returns("/nonexisting/two.json")

          Backend.expects(:datasources).multiple_yields(["one"], ["two"])

          File.expects(:exist?).with("/nonexisting/one.json").returns(true)
          File.expects(:exist?).with("/nonexisting/two.json").returns(true)

          @cache.expects(:read_file).with("/nonexisting/one.json", Hash).returns({"key" => "answer"})
          @cache.expects(:read_file).with("/nonexisting/two.json", Hash).returns({"key" => "answer"})

          expect(@backend.lookup("key", {}, nil, :array, nil)).to eq(["answer", "answer"])
        end

        it "should parse the answer for scope variables" do
          Backend.stubs(:parse_answer).with('test_%{rspec}', {'rspec' => 'test'}, {}, anything).returns("test_test")
          Backend.expects(:datasources).yields("one")
          Backend.expects(:datafile).with(:json, {"rspec" => "test"}, "one", "json").returns("/nonexisting/one.json")

          File.expects(:exist?).with("/nonexisting/one.json").returns(true)
          @cache.expects(:read_file).with("/nonexisting/one.json", Hash).returns({"key" => "test_%{rspec}"})

          expect(@backend.lookup("key", {"rspec" => "test"}, nil, :priority, nil)).to eq("test_test")
        end
      end
    end
  end
end
