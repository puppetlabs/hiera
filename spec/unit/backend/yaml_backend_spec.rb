require 'spec_helper'
require 'hiera/backend/yaml_backend'

class Hiera
  module Backend
    describe Yaml_backend do
      before do
        Config.load({})
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @cache = mock
        @backend = Yaml_backend.new(@cache)
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
          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>"answer"})
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          @backend.lookup("key", {}, nil, :priority).should == "answer"
        end

        it "should not look up missing data files" do
          Backend.expects(:datasources).multiple_yields(["one"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns(nil)
          YAML.expects(:load_file).never

          @backend.lookup("key", {}, nil, :priority)
        end

        it "should return nil for empty data files" do
          Backend.expects(:datasources).multiple_yields(["one"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({})

          @backend.lookup("key", {}, nil, :priority).should be_nil
        end

        it "should build an array of all data sources for array searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>"answer"})
          @cache.expects(:read).with("/nonexisting/two.yaml", Hash, {}).returns({"key"=>"answer"})

          @backend.lookup("key", {}, nil, :array).should == ["answer", "answer"]
        end

        it "should ignore empty hash of data sources for hash searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({})
          @cache.expects(:read).with("/nonexisting/two.yaml", Hash, {}).returns({"key"=>{"a"=>"answer"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer"}
        end

        it "should build a merged hash of data sources for hash searches" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read).with("/nonexisting/two.yaml", Hash, {}).returns({"key"=>{"b"=>"answer", "a"=>"wrong"}})

          @backend.lookup("key", {}, nil, :hash).should == {"a" => "answer", "b" => "answer"}
        end

        it "should fail when trying to << a Hash" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>["a", "answer"]})
          @cache.expects(:read).with("/nonexisting/two.yaml", Hash, {}).returns({"key"=>{"a"=>"answer"}})

          expect {@backend.lookup("key", {}, nil, :array)}.to raise_error(Exception, "Hiera type mismatch: expected Array and got Hash")
        end

        it "should fail when trying to merge an Array" do
          Backend.expects(:datasources).multiple_yields(["one"], ["two"])
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml")
          Backend.expects(:datafile).with(:yaml, {}, "two", "yaml").returns("/nonexisting/two.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)
          File.stubs(:exist?).with("/nonexisting/two.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read).with("/nonexisting/two.yaml", Hash, {}).returns({"key"=>["a", "wrong"]})

          expect { @backend.lookup("key", {}, nil, :hash) }.to raise_error(Exception, "Hiera type mismatch: expected Hash and got Array")
        end

        it "should parse the answer for scope variables" do
          Backend.expects(:datasources).yields("one")
          Backend.expects(:datafile).with(:yaml, {"rspec" => "test"}, "one", "yaml").returns("/nonexisting/one.yaml")
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).returns({"key"=>"test_%{rspec}"})

          @backend.lookup("key", {"rspec" => "test"}, nil, :priority).should == "test_test"
        end

        it "should retain datatypes found in yaml files" do
          Backend.expects(:datasources).yields("one").times(3)
          Backend.expects(:datafile).with(:yaml, {}, "one", "yaml").returns("/nonexisting/one.yaml").times(3)
          File.stubs(:exist?).with("/nonexisting/one.yaml").returns(true)

          yaml = "---\nstringval: 'string'\nboolval: true\nnumericval: 1"

          @cache.expects(:read).with("/nonexisting/one.yaml", Hash, {}).times(3).returns({"boolval"=>true, "numericval"=>1, "stringval"=>"string"})

          @backend.lookup("stringval", {}, nil, :priority).should == "string"
          @backend.lookup("boolval", {}, nil, :priority).should == true
          @backend.lookup("numericval", {}, nil, :priority).should == 1
        end
      end
    end
  end
end
