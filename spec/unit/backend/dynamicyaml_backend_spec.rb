require 'spec_helper'
require 'hiera/backend/dynamicyaml_backend'

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

    describe Dynamicyaml_backend do
      before do
        Config.load({})
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        @cache = FakeCache.new
        @backend = Dynamicyaml_backend.new(@cache)
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera Dynamic YAML backend starting")
          Dynamicyaml_backend.new
        end
      end

      describe "#lookup" do
        it "should pick data earliest source that has it for priority searches" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
          @cache.value = "---\nkey: answer"

          expect(@backend.lookup("key", {}, nil, :priority, nil)).to eq("answer")
        end

        describe "handling unexpected YAML values" do
          before do
            @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).yields(["one", "/nonexisting/one.yaml"])
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
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])
          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"answer"})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>"answer"})

          expect(@backend.lookup("key", {}, nil, :array, nil)).to eq(["answer", "answer"])
        end

        it "should ignore empty hash of data sources for hash searches" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          expect(@backend.lookup("key", {}, nil, :hash, nil)).to eq({"a" => "answer"})
        end

        it "should build a merged hash of data sources for hash searches" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"b"=>"answer", "a"=>"wrong"}})

          expect(@backend.lookup("key", {}, nil, :hash, nil)).to eq({"a" => "answer", "b" => "answer"})
        end

        it "should fail when trying to << a Hash" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>["a", "answer"]})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>{"a"=>"answer"}})

          expect {@backend.lookup("key", {}, nil, :array, nil)}.to raise_error(Exception, "Hiera type mismatch for key 'key': expected Array and got Hash")
        end

        it "should fail when trying to merge an Array" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"], ["two", "/nonexisting/two.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>{"a"=>"answer"}})
          @cache.expects(:read_file).with("/nonexisting/two.yaml", Hash).returns({"key"=>["a", "wrong"]})

          expect { @backend.lookup("key", {}, nil, :hash, nil) }.to raise_error(Exception, "Hiera type mismatch for key 'key': expected Hash and got Array")
        end

        it "should parse the answer for scope variables" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {"rspec" => "test"}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"])

          @cache.expects(:read_file).with("/nonexisting/one.yaml", Hash).returns({"key"=>"test_%{rspec}"})

          expect(@backend.lookup("key", {"rspec" => "test"}, nil, :priority, nil)).to eq("test_test")
        end

        it "should retain datatypes found in yaml files" do
          @backend.expects(:datasourcefiles).with(:dynamicyaml, {}, "yaml", nil).multiple_yields(["one", "/nonexisting/one.yaml"]).times(3)


          @cache.value = "---\nstringval: 'string'\nboolval: true\nnumericval: 1"

          expect(@backend.lookup("stringval", {}, nil, :priority, nil)).to eq("string")
          expect(@backend.lookup("boolval", {}, nil, :priority, nil)).to eq(true)
          expect(@backend.lookup("numericval", {}, nil, :priority, nil)).to eq(1)
        end
      end

      describe "#datasources" do

        it "dynamically expands data sources with specified array property" do
          Config.load({:dynamicyaml => {:dynamic_prop => :env}})

          scope = {role: "foo", env: ["sub_lab", "lab"]}

          scope_sub_lab = scope.clone
          scope_sub_lab[:env] = "sub_lab"

          scope_lab = scope.clone
          scope_lab[:env] = "lab"

          Backend.expects(:interpolate_config).with("%{role}", scope_sub_lab, nil).returns("foo")
          Backend.expects(:interpolate_config).with("%{role}", scope_lab, nil).returns("foo")
          Backend.expects(:interpolate_config).with("env/%{env}", scope_sub_lab, nil).returns("env/sub_lab")
          Backend.expects(:interpolate_config).with("env/%{env}", scope_lab, nil).returns("env/lab")

          expected = ["foo", "env/sub_lab", "env/lab"]
          @backend.datasources(scope, nil, ["%{role}", "env/%{env}"]) do |backend|
            expect(backend).to eq(expected.delete_at(0))
          end

          expect(expected.empty?).to eq(true)
        end

        it "iterates over the datasources in the order of the given hierarchy" do
          expected = ["one", "two"]
          @backend.datasources({}, nil, ["one", "two"]) do |backend|
            expect(backend).to eq(expected.delete_at(0))
          end

          expect(expected.empty?).to eq(true)
        end

        it "uses the configured hierarchy no specific hierarchy is given" do
          Config.load(:hierarchy => "test")

          @backend.datasources({}) do |backend|
            expect(backend).to eq("test")
          end
        end

        it "defaults to a hierarchy of only 'common' if not configured or given" do
          Config.load({})

          @backend.datasources({}) do |backend|
            expect(backend).to eq("common")
          end
        end

        it "prefixes the hierarchy with the override if an override is provided" do
          Config.load({})

          expected = ["override", "common"]
          @backend.datasources({}, "override") do |backend|
            expect(backend).to eq(expected.delete_at(0))
          end

          expect(expected.empty?).to eq(true)
        end

        it "parses the names of the hierarchy levels using the given scope" do
          Backend.expects(:interpolate_config).with('nodes/%{::trusted.certname}', {:rspec => :tests}, nil)
          Backend.expects(:interpolate_config).with('common', {:rspec => :tests}, nil)
          @backend.datasources({:rspec => :tests}) { }
        end

        it "defaults to 'common' if the hierarchy contains no hierarchies with non-empty names" do
          Config.load({})

          expected = ["common"]
          @backend.datasources({}, "%{rspec}") do |backend|
            expect(backend).to eq(expected.delete_at(0))
          end

          expect(expected.empty?).to eq(true)
        end
      end
    end
  end
end
