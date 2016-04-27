require 'spec_helper'
require 'hiera/util'

class Hiera
  module Backend
    class Backend1x_backend
      def lookup(key, scope, order_override, resolution_type)
        ["a", "b"]
      end
    end
  end

  describe Backend do
    describe "loading non existing backend" do
      it "fails if a backend cannot be loaded" do
        Config.load({:datadir => "/tmp/%{interpolate}", :backends => ['bogus']})
        expect do
          Config.load_backends
        end.to raise_error(/Cannot load backend bogus/)
      end
    end

    describe "#datadir" do
      it "interpolates any values in the configured value" do
        Config.load({:rspec => {:datadir => "/tmp/%{interpolate}"}})

        dir = Backend.datadir(:rspec, { "interpolate" => "my_data" })

        expect(dir).to eq("/tmp/my_data")
      end

      it "defaults to a directory in var" do
        Config.load({})
        expect(Backend.datadir(:rspec, { "environment" => "foo" })).to eq(Hiera::Util.var_dir % { :environment => "foo"})

        Config.load({:rspec => nil})
        expect(Backend.datadir(:rspec, { "environment" => "foo" })).to eq(Hiera::Util.var_dir % { :environment => "foo"})

        Config.load({:rspec => {}})
        expect(Backend.datadir(:rspec, { "environment" => "foo" })).to eq(Hiera::Util.var_dir % { :environment => "foo"})
      end

      it "fails when the datadir is an array" do
        Config.load({:rspec => {:datadir => []}})

        expect do
          Backend.datadir(:rspec, {})
        end.to raise_error(Hiera::InvalidConfigurationError, /datadir for rspec cannot be an array/)
      end
    end

    describe "#datafile" do
      it "translates a non-existant datafile into nil" do
        Hiera.expects(:debug).with("Cannot find datafile /nonexisting/test.yaml, skipping")
        Backend.expects(:datadir).returns("/nonexisting")
        expect(Backend.datafile(:yaml, {}, "test", "yaml")).to eq(nil)
      end

      it "concatenates the datadir and datafile and format to produce the full datafile filename" do
        Backend.expects(:datadir).returns("/nonexisting")
        File.expects(:exist?).with("/nonexisting/test.yaml").returns(true)
        expect(Backend.datafile(:yaml, {}, "test", "yaml")).to eq("/nonexisting/test.yaml")
      end
    end

    describe "#datasources" do
      it "iterates over the datasources in the order of the given hierarchy" do
        expected = ["one", "two"]
        Backend.datasources({}, nil, ["one", "two"]) do |backend|
          expect(backend).to eq(expected.delete_at(0))
        end

        expect(expected.empty?).to eq(true)
      end

      it "uses the configured hierarchy no specific hierarchy is given" do
        Config.load(:hierarchy => "test")

        Backend.datasources({}) do |backend|
          expect(backend).to eq("test")
        end
      end

      it "defaults to a hierarchy of only 'common' if not configured or given" do
        Config.load({})

        Backend.datasources({}) do |backend|
          expect(backend).to eq("common")
        end
      end

      it "prefixes the hierarchy with the override if an override is provided" do
        Config.load({})

        expected = ["override", "common"]
        Backend.datasources({}, "override") do |backend|
          expect(backend).to eq(expected.delete_at(0))
        end

        expect(expected.empty?).to eq(true)
      end

      it "parses the names of the hierarchy levels using the given scope" do
        Backend.expects(:interpolate_config).with('nodes/%{::trusted.certname}', {:rspec => :tests}, nil)
        Backend.expects(:interpolate_config).with('common', {:rspec => :tests}, nil)
        Backend.datasources({:rspec => :tests}) { }
      end

      it "defaults to 'common' if the hierarchy contains no hierarchies with non-empty names" do
        Config.load({})

        expected = ["common"]
        Backend.datasources({}, "%{rspec}") do |backend|
          expect(backend).to eq(expected.delete_at(0))
        end

        expect(expected.empty?).to eq(true)
      end
    end

    describe "#parse_string" do
      it "passes nil through untouched" do
        expect(Backend.parse_string(nil, {})).to eq(nil)
      end

      it "does not modify the input data" do
        data = "%{value}"
        Backend.parse_string(data, { "value" => "replacement" })

        expect(data).to eq("%{value}")
      end

      it "passes non-string data through untouched" do
        input = { "not a" => "string" }

        expect(Backend.parse_string(input, {})).to eq(input)
      end

      @scope_interpolation_tests = {
        "replace %{part1} and %{part2}" =>
          "replace value of part1 and value of part2",
        "replace %{scope('part1')} and %{scope('part2')}" =>
          "replace value of part1 and value of part2"
      }

      @scope_interpolation_tests.each do |input, expected|
        it "replaces interpolations with data looked up in the scope" do
          scope = {"part1" => "value of part1", "part2" => "value of part2"}

          expect(Backend.parse_string(input, scope)).to eq(expected)
        end
      end

      it "replaces interpolations with data looked up in extra_data when scope does not contain the value" do
        input = "test_%{rspec}_test"
        expect(Backend.parse_string(input, {}, {"rspec" => "extra"})).to eq("test_extra_test")
      end

      it "prefers data from scope over data from extra_data" do
        input = "test_%{rspec}_test"
        expect(Backend.parse_string(input, {"rspec" => "test"}, {"rspec" => "fail"})).to eq("test_test_test")
      end

      @interprets_nil_in_scope_tests = {
        "test_%{rspec}_test" => "test__test",
        "test_%{scope('rspec')}_test" => "test__test"
      }

      @interprets_nil_in_scope_tests.each do |input, expected|
        it "interprets nil in scope as a non-value" do
          expect(Backend.parse_string(input, {"rspec" => nil})).to eq(expected)
        end
      end

      @interprets_false_in_scope_tests = {
        "test_%{rspec}_test" => "test_false_test",
        "test_%{scope('rspec')}_test" => "test_false_test"
      }

      @interprets_false_in_scope_tests.each do |input, expected|
        it "interprets false in scope as a real value" do
          input = "test_%{scope('rspec')}_test"
          expect(Backend.parse_string(input, {"rspec" => false})).to eq(expected)
        end
      end

      it "interprets false in extra_data as a real value" do
        input = "test_%{rspec}_test"
        expect(Backend.parse_string(input, {}, {"rspec" => false})).to eq("test_false_test")
      end

      it "interprets nil in extra_data as a non-value" do
        input = "test_%{rspec}_test"
        expect(Backend.parse_string(input, {}, {"rspec" => nil})).to eq("test__test")
      end

      @interprets_undefined_in_scope_tests = {
        "test_%{rspec}_test" => "test__test",
        "test_%{scope('rspec')}_test" => "test__test"
      }

      @exact_lookup_tests = {
        "test_%{::rspec::data}_test" => "test_value_test",
        "test_%{scope('::rspec::data')}_test" => "test_value_test"
      }

      @exact_lookup_tests.each do |input, expected|
        it "looks up the interpolated value exactly as it appears in the input" do
          expect(Backend.parse_string(input, {"::rspec::data" => "value"})).to eq(expected)
        end
      end

      @surrounding_whitespace_tests = {
        "test_%{\trspec::data }_test" => "test_value_test",
        "test_%{scope('\trspec::data ')}_test" => "test_value_test"
      }
      @surrounding_whitespace_tests.each do |input, expected|
        it "does not remove any surrounding whitespace when parsing the key to lookup" do
          expect(Backend.parse_string(input, {"\trspec::data " => "value"})).to eq(expected)
        end
      end

      @leading_double_colon_tests = {
        "test_%{::rspec::data}_test" => "test__test",
        "test_%{scope('::rspec::data')}_test" => "test__test"
      }

      @leading_double_colon_tests.each do |input, expected|
        it "does not try removing leading :: when a full lookup fails (#17434)" do
          expect(Backend.parse_string(input, {"rspec::data" => "value"})).to eq(expected)
        end
      end

      @double_colon_key_tests = {
        "test_%{::rspec::data}_test" => "test__test",
        "test_%{scope('::rspec::data')}_test" => "test__test"
      }
      @double_colon_key_tests.each do |input, expected|
        it "does not try removing leading sections separated by :: when a full lookup fails (#17434)" do
          expect(Backend.parse_string(input, {"data" => "value"})).to eq(expected)
        end
      end

      it "does not try removing unknown, preceeding characters when looking up values" do
        input = "test_%{$var}_test"
        expect(Backend.parse_string(input, {"$var" => "value"})).to eq("test_value_test")
      end

      it "looks up recursively" do
        scope = {"rspec" => "%{first}", "first" => "%{last}", "last" => "final"}
        input = "test_%{rspec}_test"
        expect(Backend.parse_string(input, scope)).to eq("test_final_test")
      end

      it "raises an error if the recursive lookup results in an infinite loop" do
        scope = {"first" => "%{second}", "second" => "%{first}"}
        input = "test_%{first}_test"
        expect do
          Backend.parse_string(input, scope)
        end.to raise_error Hiera::InterpolationLoop, "Lookup recursion detected in [first, second]"
      end

      it "replaces repeated occurances of the same lookup" do
        scope = {"rspec" => "value"}
        input = "it replaces %{rspec} and %{rspec}"
        expect(Backend.parse_string(input, scope)).to eq("it replaces value and value")
      end

      it "replaces hiera interpolations with data looked up in hiera" do
        input = "%{hiera('key1')}"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("key1", scope, nil, :priority, instance_of(Hash)).returns("answer")

        expect(Backend.parse_string(input, scope)).to eq("answer")
      end

      it "interpolation passes the order_override back into the backend" do
        Backend.expects(:lookup).with("lookup::key", nil, {}, "order_override_datasource", :priority, instance_of(Hash))
        Backend.parse_string("%{hiera('lookup::key')}", {}, {}, {:order_override => "order_override_datasource"})
      end

      it "replaces literal interpolations with their argument" do
        scope = {}
        input = "%{literal('%')}{rspec::data}"
        expect(Backend.parse_string(input, scope)).to eq("%{rspec::data}")
      end
    end

    describe "#parse_answer" do
      it "interpolates values in strings" do
        input = "test_%{rspec}_test"
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq("test_test_test")
      end

      it "interpolates each string in an array" do
        input = ["test_%{rspec}_test", "test_%{rspec}_test", ["test_%{rspec}_test"]]
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq(["test_test_test", "test_test_test", ["test_test_test"]])
      end

      it "interpolates each string in a hash" do
        input = {"foo" => "test_%{rspec}_test", "bar" => "test_%{rspec}_test"}
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq({"foo"=>"test_test_test", "bar"=>"test_test_test"})
      end

      it "interpolates string in hash keys" do
        input = {"%{rspec}" => "test"}
        expect(Backend.parse_answer(input, {"rspec" => "foo"})).to eq({"foo"=>"test"})
      end

      it "interpolates strings in nested hash keys" do
        input = {"topkey" => {"%{rspec}" => "test"}}
        expect(Backend.parse_answer(input, {"rspec" => "foo"})).to eq({"topkey"=>{"foo" => "test"}})
      end

      it "interpolates strings in a mixed structure of arrays and hashes" do
        input = {"foo" => "test_%{rspec}_test", "bar" => ["test_%{rspec}_test", "test_%{rspec}_test"]}
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq({"foo"=>"test_test_test", "bar"=>["test_test_test", "test_test_test"]})
      end

      it "interpolates hiera lookups values in strings" do
        input = "test_%{hiera('rspec')}_test"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("test")
        expect(Backend.parse_answer(input, scope)).to eq("test_test_test")
      end

      it "interpolates alias lookups with non-string types" do
        input = "%{alias('rspec')}"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns(['test', 'test'])
        expect(Backend.parse_answer(input, scope)).to eq(['test', 'test'])
      end

      it 'fails if alias interpolation is attempted in a string context with a prefix' do
        input = "stuff_before%{alias('rspec')}"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns(['test', 'test'])
        expect do
          expect(Backend.parse_answer(input, scope)).to eq(['test', 'test'])
        end.to raise_error(Hiera::InterpolationInvalidValue, 'Cannot call alias in the string context')
      end

      it 'fails if alias interpolation is attempted in a string context with a postfix' do
        input = "%{alias('rspec')}_stiff after"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns(['test', 'test'])
        expect do
          expect(Backend.parse_answer(input, scope)).to eq(['test', 'test'])
        end.to raise_error(Hiera::InterpolationInvalidValue, 'Cannot call alias in the string context')
      end

      it "interpolates hiera lookups in each string in an array" do
        input = ["test_%{hiera('rspec')}_test", "test_%{hiera('rspec')}_test", ["test_%{hiera('rspec')}_test"]]
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("test")
        expect(Backend.parse_answer(input, scope)).to eq(["test_test_test", "test_test_test", ["test_test_test"]])
      end

      it "interpolates hiera lookups in each string in a hash" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => "test_%{hiera('rspec')}_test"}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("test")
        expect(Backend.parse_answer(input, scope)).to eq({"foo"=>"test_test_test", "bar"=>"test_test_test"})
      end

      it "interpolates hiera lookups in string in hash keys" do
        input = {"%{hiera('rspec')}" => "test"}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("foo")
        expect(Backend.parse_answer(input, scope)).to eq({"foo"=>"test"})
      end

      it "interpolates hiera lookups in strings in nested hash keys" do
        input = {"topkey" => {"%{hiera('rspec')}" => "test"}}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("foo")
        expect(Backend.parse_answer(input, scope)).to eq({"topkey"=>{"foo" => "test"}})
      end

      it "interpolates hiera lookups in strings in a mixed structure of arrays and hashes" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => ["test_%{hiera('rspec')}_test", "test_%{hiera('rspec')}_test"]}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("test")
        expect(Backend.parse_answer(input, scope)).to eq({"foo"=>"test_test_test", "bar"=>["test_test_test", "test_test_test"]})
      end

      it "interpolates hiera lookups and scope lookups in the same string" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => "test_%{rspec2}_test"}
        scope = {"rspec2" => "scope_rspec"}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("hiera_rspec")
        expect(Backend.parse_answer(input, scope)).to eq({"foo"=>"test_hiera_rspec_test", "bar"=>"test_scope_rspec_test"})
      end

      it "interpolates hiera and scope lookups with the same lookup query in a single string" do
        input =  "test_%{hiera('rspec')}_test_%{rspec}"
        scope = {"rspec" => "scope_rspec"}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority, instance_of(Hash)).returns("hiera_rspec")
        expect(Backend.parse_answer(input, scope)).to eq("test_hiera_rspec_test_scope_rspec")
      end

      it "passes integers unchanged" do
        input = 1
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq(1)
      end

      it "passes floats unchanged" do
        input = 0.233
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq(0.233)
      end

      it "passes the boolean true unchanged" do
        input = true
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq(true)
      end

      it "passes the boolean false unchanged" do
        input = false
        expect(Backend.parse_answer(input, {"rspec" => "test"})).to eq(false)
      end

      it "interpolates lookups using single or double quotes" do
        input =  "test_%{scope(\"rspec\")}_test_%{scope('rspec')}"
        scope = {"rspec" => "scope_rspec"}
        expect(Backend.parse_answer(input, scope)).to eq("test_scope_rspec_test_scope_rspec")
      end
    end

    describe "#resolve_answer" do
      it "flattens and removes duplicate values from arrays during an array lookup" do
        expect(Backend.resolve_answer(["foo", ["foo", "foo"], "bar"], :array)).to eq(["foo", "bar"])
      end

      it "returns the data unchanged during a priority lookup" do
        expect(Backend.resolve_answer(["foo", ["foo", "foo"], "bar"], :priority)).to eq(["foo", ["foo", "foo"], "bar"])
      end
    end

    describe "#lookup" do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
      end

      it "caches loaded backends" do
        Backend.clear!
        Hiera.expects(:debug).with(regexp_matches(/Hiera YAML backend starting/)).once

        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend.lookup("key", "default", {}, nil, nil)
        Backend.lookup("key", "default", {}, nil, nil)
      end

      it "returns the answer from the backend" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, nil, instance_of(Hash)).returns("answer")

        expect(Backend.lookup("key", "default", {}, nil, nil)).to eq("answer")
      end

      it "retains the datatypes as returned by the backend" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("stringval", {}, nil, nil, instance_of(Hash)).returns("string")
        Backend::Yaml_backend.any_instance.expects(:lookup).with("boolval", {}, nil, nil, instance_of(Hash)).returns(false)
        Backend::Yaml_backend.any_instance.expects(:lookup).with("numericval", {}, nil, nil, instance_of(Hash)).returns(1)

        expect(Backend.lookup("stringval", "default", {}, nil, nil)).to eq("string")
        expect(Backend.lookup("boolval", "default", {}, nil, nil)).to eq(false)
        expect(Backend.lookup("numericval", "default", {}, nil, nil)).to eq(1)
      end

      it "calls to all backends till an answer is found" do
        backend = mock
        backend.expects(:lookup).returns("answer")
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        #Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil)
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        expect(Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil)).to eq("answer")
      end

      it "calls to all backends till an answer is found when doing array lookups" do
        backend = mock
        backend.expects(:lookup).returns(["answer"])
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        expect(Backend.lookup("key", "notfound", {"rspec" => "test"}, nil, :array)).to eq(["answer"])
      end

      it "calls to all backends till an answer is found when doing hash lookups" do
        thehash = {:answer => "value"}
        backend = mock
        backend.expects(:lookup).returns(thehash)
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        expect(Backend.lookup("key", "notfound", {"rspec" => "test"}, nil, :hash)).to eq(thehash)
      end

      it "builds a merged hash from all backends for hash searches" do
        backend1 = mock :lookup => {"a" => "answer"}
        backend2 = mock :lookup => {"b" => "bnswer"}
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["first", "second"]})
        Backend.instance_variable_set("@backends", {"first" => backend1, "second" => backend2})
        Backend.stubs(:constants).returns(["First_backend", "Second_backend"])

        expect(Backend.lookup("key", {}, {"rspec" => "test"}, nil, :hash)).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "builds an array from all backends for array searches" do
        backend1 = mock :lookup => ["a", "b"]
        backend2 = mock :lookup => ["c", "d"]
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["first", "second"]})
        Backend.instance_variable_set("@backends", {"first" => backend1, "second" => backend2})
        Backend.stubs(:constants).returns(["First_backend", "Second_backend"])

        expect(Backend.lookup("key", {}, {"rspec" => "test"}, nil, :array)).to eq(["a", "b", "c", "d"])
      end

      it "uses the earliest backend result for priority searches" do
        backend1 = mock
        backend1.stubs(:lookup).returns(["a", "b"])
        backend2 = mock
        backend2.stubs(:lookup).returns(["c", "d"])
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["first", "second"]})
        Backend.instance_variable_set("@backends", {"first" => backend1, "second" => backend2})
        Backend.stubs(:constants).returns(["First_backend", "Second_backend"])

        expect(Backend.lookup("key", {}, {"rspec" => "test"}, nil, :priority)).to eq(["a", "b"])
      end

      it "parses the answers based on resolution_type" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend.expects(:resolve_answer).with("test_test", :priority).returns("parsed")
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, :priority, instance_of(Hash)).returns("test_test")

        expect(Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, :priority)).to eq("parsed")
      end

      it "returns the default with variables parsed if nothing is found" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil, instance_of(Hash)).throws(:no_such_key)

        expect(Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil)).to eq("test_test")
      end

      it "returns nil instead of the default when key is found with a nil value" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil, instance_of(Hash)).returns(nil)

        expect(Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil)).to eq(nil)
      end

      it "keeps string default data as a string" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, nil, instance_of(Hash)).throws(:no_such_key)
        expect(Backend.lookup("key", "test", {}, nil, nil)).to eq("test")
      end

      it "keeps array default data as an array" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, :array, instance_of(Hash)).throws(:no_such_key)
        expect(Backend.lookup("key", ["test"], {}, nil, :array)).to eq(["test"])
      end

      it "keeps hash default data as a hash" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, :hash, instance_of(Hash)).throws(:no_such_key)
        expect(Backend.lookup("key", {"test" => "value"}, {}, nil, :hash)).to eq({"test" => "value"})
      end

      it 'can use qualified key to lookup value in hash' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns({ 'test' => 'value'})
        expect(Backend.lookup('key.test', 'dflt', {}, nil, nil)).to eq('value')
      end

      it 'can use qualified key to lookup value in array' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns([ 'first', 'second'])
        expect(Backend.lookup('key.1', 'dflt', {}, nil, nil)).to eq('second')
      end

      it 'will fail when qualified key is partially found but not expected hash' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns(['value 1', 'value 2'])
        expect do
          Backend.lookup('key.test', 'dflt', {}, nil, nil)
        end.to raise_error(Exception, /^Hiera type mismatch:/)
      end

      it 'will fail when qualified key used with resolution_type :hash' do
        expect do
          Backend.lookup('key.test', 'dflt', {}, nil, :hash)
        end.to raise_error(ArgumentError, /^Resolution type :hash is illegal/)
      end

      it 'will fail when qualified key used with resolution_type :array' do
        expect do
          Backend.lookup('key.test', 'dflt', {}, nil, :array)
        end.to raise_error(ArgumentError, /^Resolution type :array is illegal/)
      end

      it 'will succeed when qualified key used with resolution_type :priority' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, :priority, instance_of(Hash)).returns({ 'test' => 'value'})
        expect(Backend.lookup('key.test', 'dflt', {}, nil, :priority)).to eq('value')
      end

      it 'will fail when qualified key is partially found but not expected array' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns({ 'test' => 'value'})
        expect do
          Backend.lookup('key.2', 'dflt', {}, nil, nil)
        end.to raise_error(Exception, /^Hiera type mismatch:/)
      end

      it 'will not fail when qualified key is partially not found' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns(nil)
        expect(Backend.lookup('key.test', 'dflt', {}, nil, nil)).to eq('dflt')
      end

      it 'will not fail when qualified key is array index out of bounds' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns(['value 1', 'value 2'])
        expect(Backend.lookup('key.33', 'dflt', {}, nil, nil)).to eq('dflt')
      end

      it 'will fail when dotted key access is made using a numeric index and value is not array' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns(
          {'one' => 'value 1', 'two' => 'value 2'})
        expect {Backend.lookup('key.33', 'dflt', {}, nil, nil)}.to raise_error(Exception,
          /Got Hash when Array was expected to access value using '33' from key 'key.33'/)
      end

      it 'will fail when dotted key access is made using a string and value is not hash' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', {}, nil, nil, instance_of(Hash)).returns(
          ['value 1', 'value 2'])
        expect {Backend.lookup('key.one', 'dflt', {}, nil, nil)}.to raise_error(Exception,
          /Got Array when a hash-like object was expected to access value using 'one' from key 'key.one'/)
      end

      it 'will fail when dotted key access is made using resolution type :hash' do
        expect {Backend.lookup('key.one', 'dflt', {}, nil, :hash)}.to raise_error(Exception,
          /Resolution type :hash is illegal when accessing values using dotted keys. Offending key was 'key.one'/)
      end

      it 'will fail when dotted key access is made using resolution type :array' do
        expect {Backend.lookup('key.one', 'dflt', {}, nil, :array)}.to raise_error(Exception,
          /Resolution type :array is illegal when accessing values using dotted keys. Offending key was 'key.one'/)
      end

      it 'can use qualified key in interpolation to lookup value in hash' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        Hiera::Backend.stubs(:datasourcefiles).yields('foo', 'bar')
        Hiera::Filecache.any_instance.expects(:read_file).at_most(2).returns({'key' => '%{hiera(\'some.subkey\')}', 'some' => { 'subkey' => 'value' }})
        expect(Backend.lookup('key', 'dflt', {}, nil, nil)).to eq('value')
      end

      it 'can use qualified key in interpolated default and scope' do
        Config.load({:yaml => {:datadir => '/tmp'}})
        Config.load_backends
        scope = { 'some' => { 'test' => 'value'}}
        Backend::Yaml_backend.any_instance.expects(:lookup).with('key', scope, nil, nil, instance_of(Hash))
        expect(Backend.lookup('key.notfound', '%{some.test}', scope, nil, nil)).to eq('value')
      end

      it "handles older backend with 4 argument lookup" do
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["Backend1x"]})

        Hiera.expects(:debug).at_least_once.with(regexp_matches /Using Hiera 1.x backend/)
        expect(Backend.lookup("key", {}, {"rspec" => "test"}, nil, :priority)).to eq(["a", "b"])
      end
    end

    describe '#merge_answer' do
      before do
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        Config.stubs(:validate!)
      end

      it "uses Hash.merge when configured with :merge_behavior => :native" do
        Config.load({:merge_behavior => :native})
        Hash.any_instance.expects(:merge).with({"b" => "bnswer"}).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"})).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "uses deep_merge! when configured with :merge_behavior => :deeper" do
        Config.load({:merge_behavior => :deeper})
        Hash.any_instance.expects('deeper_merge!').with({"b" => "bnswer"}, {}).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"})).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "uses deep_merge when configured with :merge_behavior => :deep" do
        Config.load({:merge_behavior => :deep})
        Hash.any_instance.expects('deeper_merge').with({"b" => "bnswer"}, {}).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"})).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "disregards configuration when 'merge' parameter is given as a Hash" do
        Config.load({:merge_behavior => :deep})
        Hash.any_instance.expects('deeper_merge!').with({"b" => "bnswer"}, {}).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"}, {:behavior => 'deeper' })).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "propagates deep merge options when given Hash 'merge' parameter" do
        Hash.any_instance.expects('deeper_merge!').with({"b" => "bnswer"}, { :knockout_prefix => '-' }).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"}, {:behavior => 'deeper', :knockout_prefix => '-'})).to eq({"a" => "answer", "b" => "bnswer"})
      end

      it "passes Config[:deep_merge_options] into calls to deep_merge" do
        Config.load({:merge_behavior => :deep, :deep_merge_options => { :knockout_prefix => '-' } })
        Hash.any_instance.expects('deeper_merge').with({"b" => "bnswer"}, {:knockout_prefix => '-'}).returns({"a" => "answer", "b" => "bnswer"})
        expect(Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"})).to eq({"a" => "answer", "b" => "bnswer"})
      end
    end
  end
end
