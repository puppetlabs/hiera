require 'spec_helper'
require 'hiera/backend/yaml_backend'

class Hiera
  module Backend
    class FakeCache
      attr_accessor :value
      def read(path, expected_type, default, &block)
        read_file(path, expected_type, &block)
      rescue => e
        default
      end

      def read_file(path, expected_type, &block)
        output = block.call(@value)
        if !output.is_a? expected_type
          raise TypeError
        end
        output
      end
    end

    describe Yaml_backend do
      before do
        Config.load({})
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @cache = FakeCache.new
        @backend = Yaml_backend.new(@cache)
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera YAML backend starting")
          Yaml_backend.new
        end
      end

      describe "#lookup" do
        it "should pick data earliest source that has it for priority searches" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          @cache.value = "---\nkey: answer"

          expect(@backend.lookup("key", {}, nil, :priority, nil)).to eq("answer")
        end

        describe "handling unexpected YAML values" do
          before do
            Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          end

          it "throws :no_such_key when key is missing in YAML" do
            @cache.value = "---\n"
            expect { @backend.lookup("key", {}, nil, :priority, nil) }.to throw_symbol(:no_such_key)
          end

          it "returns nil when the YAML value is nil" do
            @cache.value = "key: ~\n"
            expect(@backend.lookup("key", {}, nil, :priority, nil)).to be_nil
          end

          it "throws :no_such_key when the YAML file is false" do
            @cache.value = ""
            expect { @backend.lookup("key", {}, nil, :priority, nil) }.to throw_symbol(:no_such_key)
          end

          it "raises a TypeError when the YAML value is not a hash" do
            @cache.value = "---\n[one, two, three]"
            expect { @backend.lookup("key", {}, nil, :priority, nil) }.to raise_error(TypeError)
          end
        end

        it "should build an array of all data sources for array searches" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])
          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"answer"})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>"answer"})

          expect(@backend.lookup("key", {}, nil, :array, nil)).to eq(["answer", "answer"])
        end

        it "should ignore empty hash of data sources for hash searches" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          expect(@backend.lookup("key", {}, nil, :hash, nil)).to eq({"a" => "answer"})
        end

        it "should build a merged hash of data sources for hash searches" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"b"=>"answer", "a"=>"wrong"}})

          expect(@backend.lookup("key", {}, nil, :hash, nil)).to eq({"a" => "answer", "b" => "answer"})
        end

        it "should fail when trying to << a Hash" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>["a", "answer"]})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          expect {@backend.lookup("key", {}, nil, :array, nil)}.to raise_error(Exception, "Hiera type mismatch for key 'key': expected Array and got Hash")
        end

        it "should fail when trying to merge an Array" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>["a", "wrong"]})

          expect { @backend.lookup("key", {}, nil, :hash, nil) }.to raise_error(Exception, "Hiera type mismatch for key 'key': expected Hash and got Array")
        end

        it "should parse the answer for scope variables" do
          Backend.expects(:datasourcefiles).with(:yaml, {"rspec" => "test"}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"test_%{rspec}"})

          expect(@backend.lookup("key", {"rspec" => "test"}, nil, :priority, nil)).to eq("test_test")
        end

        it "should retain datatypes found in yaml files" do
          Backend.expects(:datasourcefiles).with(:yaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"]).times(3)


          @cache.value = "---\nstringval: 'string'\nboolval: true\nnumericval: 1"

          expect(@backend.lookup("stringval", {}, nil, :priority, nil)).to eq("string")
          expect(@backend.lookup("boolval", {}, nil, :priority, nil)).to eq(true)
          expect(@backend.lookup("numericval", {}, nil, :priority, nil)).to eq(1)
        end
      end
    end
  end
end
