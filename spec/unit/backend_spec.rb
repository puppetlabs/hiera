require 'spec_helper'
require 'hiera/util'

class Hiera
  describe Backend do
    describe "#datadir" do
      it "interpolates any values in the configured value" do
        Config.load({:rspec => {:datadir => "/tmp/%{interpolate}"}})

        dir = Backend.datadir(:rspec, { "interpolate" => "my_data" })

        dir.should == "/tmp/my_data"
      end

      it "defaults to a directory in var" do
        Config.load({})
        Backend.datadir(:rspec, {}).should == Hiera::Util.var_dir

        Config.load({:rspec => nil})
        Backend.datadir(:rspec, {}).should == Hiera::Util.var_dir

        Config.load({:rspec => {}})
        Backend.datadir(:rspec, {}).should == Hiera::Util.var_dir
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
        Backend.datafile(:yaml, {}, "test", "yaml").should == nil
      end

      it "concatenates the datadir and datafile and format to produce the full datafile filename" do
        Backend.expects(:datadir).returns("/nonexisting")
        File.expects(:exist?).with("/nonexisting/test.yaml").returns(true)
        Backend.datafile(:yaml, {}, "test", "yaml").should == "/nonexisting/test.yaml"
      end
    end

    describe "#datasources" do
      it "iterates over the datasources in the order of the given hierarchy" do
        expected = ["one", "two"]
        Backend.datasources({}, nil, ["one", "two"]) do |backend|
          backend.should == expected.delete_at(0)
        end

        expected.empty?.should == true
      end

      it "uses the configured hierarchy no specific hierarchy is given" do
        Config.load(:hierarchy => "test")

        Backend.datasources({}) do |backend|
          backend.should == "test"
        end
      end

      it "defaults to a hierarchy of only 'common' if not configured or given" do
        Config.load({})

        Backend.datasources({}) do |backend|
          backend.should == "common"
        end
      end

      it "prefixes the hierarchy with the override if an override is provided" do
        Config.load({})

        expected = ["override", "common"]
        Backend.datasources({}, "override") do |backend|
          backend.should == expected.delete_at(0)
        end

        expected.empty?.should == true
      end

      it "parses the names of the hierarchy levels using the given scope" do
        Backend.expects(:parse_string).with("common", {:rspec => :tests})
        Backend.datasources({:rspec => :tests}) { }
      end

      it "defaults to 'common' if the hierarchy contains no hierarchies with non-empty names" do
        Config.load({})

        expected = ["common"]
        Backend.datasources({}, "%{rspec}") do |backend|
          backend.should == expected.delete_at(0)
        end

        expected.empty?.should == true
      end
    end

    describe "#parse_string" do
      it "passes nil through untouched" do
        Backend.parse_string(nil, {}).should == nil
      end

      it "does not modify the input data" do
        data = "%{value}"
        Backend.parse_string(data, { "value" => "replacement" })

        data.should == "%{value}"
      end

      it "passes non-string data through untouched" do
        input = { "not a" => "string" }

        Backend.parse_string(input, {}).should == input
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

          Backend.parse_string(input, scope).should == expected
        end
      end

      it "replaces interpolations with data looked up in extra_data when scope does not contain the value" do
        input = "test_%{rspec}_test"
        Backend.parse_string(input, {}, {"rspec" => "extra"}).should == "test_extra_test"
      end

      it "prefers data from scope over data from extra_data" do
        input = "test_%{rspec}_test"
        Backend.parse_string(input, {"rspec" => "test"}, {"rspec" => "fail"}).should == "test_test_test"
      end

      @interprets_nil_in_scope_tests = {
        "test_%{rspec}_test" => "test__test",
        "test_%{scope('rspec')}_test" => "test__test"
      }

      @interprets_nil_in_scope_tests.each do |input, expected|
        it "interprets nil in scope as a non-value" do
          Backend.parse_string(input, {"rspec" => nil}).should == expected
        end
      end

      @interprets_false_in_scope_tests = {
        "test_%{rspec}_test" => "test_false_test",
        "test_%{scope('rspec')}_test" => "test_false_test"
      }

      @interprets_false_in_scope_tests.each do |input, expected|
        it "interprets false in scope as a real value" do
          input = "test_%{scope('rspec')}_test"
          Backend.parse_string(input, {"rspec" => false}).should == expected
        end
      end

      it "interprets false in extra_data as a real value" do
        input = "test_%{rspec}_test"
        Backend.parse_string(input, {}, {"rspec" => false}).should == "test_false_test"
      end

      it "interprets nil in extra_data as a non-value" do
        input = "test_%{rspec}_test"
        Backend.parse_string(input, {}, {"rspec" => nil}).should == "test__test"
      end

      @interprets_undefined_in_scope_tests = {
        "test_%{rspec}_test" => "test__test",
        "test_%{scope('rspec')}_test" => "test__test"
      }

      @interprets_undefined_in_scope_tests.each do |input, expected|
        it "interprets :undefined in scope as a non-value" do
          Backend.parse_string(input, {"rspec" => :undefined}).should == expected
        end
      end

      it "uses the value from extra_data when scope is :undefined" do
        input = "test_%{rspec}_test"
        Backend.parse_string(input, {"rspec" => :undefined}, { "rspec" => "extra" }).should == "test_extra_test"
      end

      @exact_lookup_tests = {
        "test_%{::rspec::data}_test" => "test_value_test",
        "test_%{scope('::rspec::data')}_test" => "test_value_test"
      }

      @exact_lookup_tests.each do |input, expected|
        it "looks up the interpolated value exactly as it appears in the input" do
          Backend.parse_string(input, {"::rspec::data" => "value"}).should == expected
        end
      end

      @surrounding_whitespace_tests = {
        "test_%{\trspec::data }_test" => "test_value_test",
        "test_%{scope('\trspec::data ')}_test" => "test_value_test"
      }
      @surrounding_whitespace_tests.each do |input, expected|
        it "does not remove any surrounding whitespace when parsing the key to lookup" do
          Backend.parse_string(input, {"\trspec::data " => "value"}).should == expected
        end
      end

      @leading_double_colon_tests = {
        "test_%{::rspec::data}_test" => "test__test",
        "test_%{scope('::rspec::data')}_test" => "test__test"
      }

      @leading_double_colon_tests.each do |input, expected|
        it "does not try removing leading :: when a full lookup fails (#17434)" do
          Backend.parse_string(input, {"rspec::data" => "value"}).should == expected
        end
      end

      @double_colon_key_tests = {
        "test_%{::rspec::data}_test" => "test__test",
        "test_%{scope('::rspec::data')}_test" => "test__test"
      }
      @double_colon_key_tests.each do |input, expected|
        it "does not try removing leading sections separated by :: when a full lookup fails (#17434)" do
          Backend.parse_string(input, {"data" => "value"}).should == expected
        end
      end

      it "does not try removing unknown, preceeding characters when looking up values" do
        input = "test_%{$var}_test"
        Backend.parse_string(input, {"$var" => "value"}).should == "test_value_test"
      end

      it "looks up recursively" do
        scope = {"rspec" => "%{first}", "first" => "%{last}", "last" => "final"}
        input = "test_%{rspec}_test"
        Backend.parse_string(input, scope).should == "test_final_test"
      end

      it "raises an error if the recursive lookup results in an infinite loop" do
        scope = {"first" => "%{second}", "second" => "%{first}"}
        input = "test_%{first}_test"
        expect do
          Backend.parse_string(input, scope)
        end.to raise_error Hiera::InterpolationLoop, "Detected in [first, second]"
      end

      it "replaces repeated occurances of the same lookup" do
        scope = {"rspec" => "value"}
        input = "it replaces %{rspec} and %{rspec}"
        Backend.parse_string(input, scope).should == "it replaces value and value"
      end

      it "replaces hiera interpolations with data looked up in hiera" do
        input = "%{hiera('key1')}"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("key1", scope, nil, :priority).returns("answer")

        Backend.parse_string(input, scope).should == "answer"
      end
    end

    describe "#parse_answer" do
      it "interpolates values in strings" do
        input = "test_%{rspec}_test"
        Backend.parse_answer(input, {"rspec" => "test"}).should == "test_test_test"
      end

      it "interpolates each string in an array" do
        input = ["test_%{rspec}_test", "test_%{rspec}_test", ["test_%{rspec}_test"]]
        Backend.parse_answer(input, {"rspec" => "test"}).should == ["test_test_test", "test_test_test", ["test_test_test"]]
      end

      it "interpolates each string in a hash" do
        input = {"foo" => "test_%{rspec}_test", "bar" => "test_%{rspec}_test"}
        Backend.parse_answer(input, {"rspec" => "test"}).should == {"foo"=>"test_test_test", "bar"=>"test_test_test"}
      end

      it "interpolates string in hash keys" do
        input = {"%{rspec}" => "test"}
        Backend.parse_answer(input, {"rspec" => "foo"}).should == {"foo"=>"test"}
      end

      it "interpolates strings in nested hash keys" do
        input = {"topkey" => {"%{rspec}" => "test"}}
        Backend.parse_answer(input, {"rspec" => "foo"}).should == {"topkey"=>{"foo" => "test"}}
      end

      it "interpolates strings in a mixed structure of arrays and hashes" do
        input = {"foo" => "test_%{rspec}_test", "bar" => ["test_%{rspec}_test", "test_%{rspec}_test"]}
        Backend.parse_answer(input, {"rspec" => "test"}).should == {"foo"=>"test_test_test", "bar"=>["test_test_test", "test_test_test"]}
      end

      it "interpolates hiera lookups values in strings" do
        input = "test_%{hiera('rspec')}_test"
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("test")
        Backend.parse_answer(input, scope).should == "test_test_test"
      end

      it "interpolates hiera lookups in each string in an array" do
        input = ["test_%{hiera('rspec')}_test", "test_%{hiera('rspec')}_test", ["test_%{hiera('rspec')}_test"]]
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("test")
        Backend.parse_answer(input, scope).should == ["test_test_test", "test_test_test", ["test_test_test"]]
      end

      it "interpolates hiera lookups in each string in a hash" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => "test_%{hiera('rspec')}_test"}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("test")
        Backend.parse_answer(input, scope).should == {"foo"=>"test_test_test", "bar"=>"test_test_test"}
      end

      it "interpolates hiera lookups in string in hash keys" do
        input = {"%{hiera('rspec')}" => "test"}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("foo")
        Backend.parse_answer(input, scope).should == {"foo"=>"test"}
      end

      it "interpolates hiera lookups in strings in nested hash keys" do
        input = {"topkey" => {"%{hiera('rspec')}" => "test"}}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("foo")
        Backend.parse_answer(input, scope).should == {"topkey"=>{"foo" => "test"}}
      end

      it "interpolates hiera lookups in strings in a mixed structure of arrays and hashes" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => ["test_%{hiera('rspec')}_test", "test_%{hiera('rspec')}_test"]}
        scope = {}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("test")
        Backend.parse_answer(input, scope).should == {"foo"=>"test_test_test", "bar"=>["test_test_test", "test_test_test"]}
      end

      it "interpolates hiera lookups and scope lookups in the same string" do
        input = {"foo" => "test_%{hiera('rspec')}_test", "bar" => "test_%{rspec2}_test"}
        scope = {"rspec2" => "scope_rspec"}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("hiera_rspec")
        Backend.parse_answer(input, scope).should == {"foo"=>"test_hiera_rspec_test", "bar"=>"test_scope_rspec_test"}
      end

      it "interpolates hiera and scope lookups with the same lookup query in a single string" do
        input =  "test_%{hiera('rspec')}_test_%{rspec}"
        scope = {"rspec" => "scope_rspec"}
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.stubs(:lookup).with("rspec", scope, nil, :priority).returns("hiera_rspec")
        Backend.parse_answer(input, scope).should == "test_hiera_rspec_test_scope_rspec"
      end

      it "passes integers unchanged" do
        input = 1
        Backend.parse_answer(input, {"rspec" => "test"}).should == 1
      end

      it "passes floats unchanged" do
        input = 0.233
        Backend.parse_answer(input, {"rspec" => "test"}).should == 0.233
      end

      it "passes the boolean true unchanged" do
        input = true
        Backend.parse_answer(input, {"rspec" => "test"}).should == true
      end

      it "passes the boolean false unchanged" do
        input = false
        Backend.parse_answer(input, {"rspec" => "test"}).should == false
      end

      it "interpolates lookups using single or double quotes" do
        input =  "test_%{scope(\"rspec\")}_test_%{scope('rspec')}"
        scope = {"rspec" => "scope_rspec"}
        Backend.parse_answer(input, scope).should == "test_scope_rspec_test_scope_rspec"
      end
    end

    describe "#resolve_answer" do
      it "flattens and removes duplicate values from arrays during an array lookup" do
        Backend.resolve_answer(["foo", ["foo", "foo"], "bar"], :array).should == ["foo", "bar"]
      end

      it "returns the data unchanged during a priority lookup" do
        Backend.resolve_answer(["foo", ["foo", "foo"], "bar"], :priority).should == ["foo", ["foo", "foo"], "bar"]
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

        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, nil).returns("answer")

        Backend.lookup("key", "default", {}, nil, nil).should == "answer"
      end

      it "retains the datatypes as returned by the backend" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("stringval", {}, nil, nil).returns("string")
        Backend::Yaml_backend.any_instance.expects(:lookup).with("boolval", {}, nil, nil).returns(false)
        Backend::Yaml_backend.any_instance.expects(:lookup).with("numericval", {}, nil, nil).returns(1)

        Backend.lookup("stringval", "default", {}, nil, nil).should == "string"
        Backend.lookup("boolval", "default", {}, nil, nil).should == false
        Backend.lookup("numericval", "default", {}, nil, nil).should == 1
      end

      it "calls to all backends till an answer is found" do
        backend = mock
        backend.expects(:lookup).returns("answer")
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        #Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil)
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil).should == "answer"
      end

      it "calls to all backends till an answer is found when doing array lookups" do
        backend = mock
        backend.expects(:lookup).returns(["answer"])
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        Backend.lookup("key", "notfound", {"rspec" => "test"}, nil, :array).should == ["answer"]
      end

      it "calls to all backends till an answer is found when doing hash lookups" do
        thehash = {:answer => "value"}
        backend = mock
        backend.expects(:lookup).returns(thehash)
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
        Backend.instance_variable_set("@backends", {"rspec" => backend})
        Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

        Backend.lookup("key", "notfound", {"rspec" => "test"}, nil, :hash).should == thehash
      end

      it "builds a merged hash from all backends for hash searches" do
        backend1 = mock :lookup => {"a" => "answer"}
        backend2 = mock :lookup => {"b" => "bnswer"}
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["first", "second"]})
        Backend.instance_variable_set("@backends", {"first" => backend1, "second" => backend2})
        Backend.stubs(:constants).returns(["First_backend", "Second_backend"])

        Backend.lookup("key", {}, {"rspec" => "test"}, nil, :hash).should == {"a" => "answer", "b" => "bnswer"}
      end

      it "builds an array from all backends for array searches" do
        backend1 = mock :lookup => ["a", "b"]
        backend2 = mock :lookup => ["c", "d"]
        Config.load({})
        Config.instance_variable_set("@config", {:backends => ["first", "second"]})
        Backend.instance_variable_set("@backends", {"first" => backend1, "second" => backend2})
        Backend.stubs(:constants).returns(["First_backend", "Second_backend"])

        Backend.lookup("key", {}, {"rspec" => "test"}, nil, :array).should == ["a", "b", "c", "d"]
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

        Backend.lookup("key", {}, {"rspec" => "test"}, nil, :priority).should == ["a", "b"]
      end

      it "parses the answers based on resolution_type" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend.expects(:resolve_answer).with("test_test", :priority).returns("parsed")
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, :priority).returns("test_test")

        Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, :priority).should == "parsed"
      end

      it "returns the default with variables parsed if nothing is found" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends

        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil)

        Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil).should == "test_test"
      end

      it "keeps string default data as a string" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, nil)
        Backend.lookup("key", "test", {}, nil, nil).should == "test"
      end

      it "keeps array default data as an array" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, :array)
        Backend.lookup("key", ["test"], {}, nil, :array).should == ["test"]
      end

      it "keeps hash default data as a hash" do
        Config.load({:yaml => {:datadir => "/tmp"}})
        Config.load_backends
        Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, :hash)
        Backend.lookup("key", {"test" => "value"}, {}, nil, :hash).should == {"test" => "value"}
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
        Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"}).should == {"a" => "answer", "b" => "bnswer"}
      end

      it "uses deep_merge! when configured with :merge_behavior => :deeper" do
        Config.load({:merge_behavior => :deeper})
        Hash.any_instance.expects('deep_merge!').with({"b" => "bnswer"}).returns({"a" => "answer", "b" => "bnswer"})
        Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"}).should == {"a" => "answer", "b" => "bnswer"}
      end

      it "uses deep_merge when configured with :merge_behavior => :deep" do
        Config.load({:merge_behavior => :deep})
        Hash.any_instance.expects('deep_merge').with({"b" => "bnswer"}).returns({"a" => "answer", "b" => "bnswer"})
        Backend.merge_answer({"a" => "answer"},{"b" => "bnswer"}).should == {"a" => "answer", "b" => "bnswer"}
      end
    end
  end
end
