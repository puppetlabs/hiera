require File.dirname(__FILE__) + '/../spec_helper'

class Hiera
    describe Backend do
        describe "#datadir" do
            it "should use the backend configured dir" do
                Config.load({:rspec => {:datadir => "/tmp"}})
                Backend.expects(:parse_string).with("/tmp", {})
                Backend.datadir(:rspec, {})
            end

            it "should default to /var/lib/hiera" do
                Config.load({})
                Backend.expects(:parse_string).with("/var/lib/hiera", {})
                Backend.datadir(:rspec, {})
            end
        end

        describe "#datasources" do
            it "should use the supplied hierarchy" do
                expected = ["one", "two"]
                Backend.datasources({}, nil, ["one", "two"]) do |backend|
                    backend.should == expected.delete_at(0)
                end
            end

            it "should use the configured hierarchy if none is supplied" do
                Config.load(:hierarchy => "test")

                Backend.datasources({}) do |backend|
                    backend.should == "test"
                end
            end

            it "should default to common if not configured or supplied" do
                Config.load({})

                Backend.datasources({}) do |backend|
                    backend.should == "common"
                end
            end

            it "should insert the override if provided" do
                Config.load({})

                expected = ["override", "common"]
                Backend.datasources({}, "override") do |backend|
                    backend.should == expected.delete_at(0)
                end
            end

            it "should parse the sources based on scope" do
                Backend.expects(:parse_string).with("common", {:rspec => :tests})
                Backend.datasources({:rspec => :tests}) { }
            end
        end

        describe "#parse_string" do
            it "should not try to parse invalid data" do
                Backend.parse_string(nil, {}).should == nil
            end

            it "should clone the supplied data" do
                data = ""
                data.expects(:clone).returns("")
                Backend.parse_string(data, {})
            end

            it "should only parse string data" do
                data = ""
                data.expects(:is_a?).with(String)
                Backend.parse_string(data, {})
            end

            it "should match data from scope" do
                input = "test_%{rspec}_test"
                Backend.parse_string(input, {"rspec" => "test"}).should == "test_test_test"
            end

            it "should match data from extra_data" do
                input = "test_%{rspec}_test"
                Backend.parse_string(input, {}, {"rspec" => "test"}).should == "test_test_test"
            end

            it "should prefer scope over extra_data" do
                input = "test_%{rspec}_test"
                Backend.parse_string(input, {"rspec" => "test"}, {"rspec" => "fail"}).should == "test_test_test"
            end
        end

        describe "#lookup" do
            before do
                Hiera.stubs(:debug)
                Hiera.stubs(:warn)
            end

            it "should cache backends" do
                Hiera.stubs(:debug)
                Hiera.expects(:debug).with(regexp_matches(/Hiera YAML backend starting/)).once

                Config.load({:yaml => {:datadir => "/tmp"}})
                Config.load_backends

                Backend.lookup("key", "default", {}, nil, nil)
                Backend.lookup("key", "default", {}, nil, nil)
            end

            it "should return the answer from the backend" do
                Hiera.stubs(:debug)
                Config.load({:yaml => {:datadir => "/tmp"}})
                Config.load_backends

                Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {}, nil, nil).returns("answer")

                Backend.lookup("key", "default", {}, nil, nil).should == "answer"
            end

            it "should call to all backends till an answer is found" do
                backend = mock
                backend.expects(:lookup).returns("answer")
                Hiera.stubs(:debug)
                Config.load({})
                Config.instance_variable_set("@config", {:backends => ["yaml", "rspec"]})
                Backend.instance_variable_set("@backends", {"rspec" => backend})
                Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil)
                Backend.expects(:constants).returns(["Yaml_backend", "Rspec_backend"]).twice

                Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil).should == "answer"

            end

            it "should return the default with variables parsed if nothing is found" do
                Hiera.stubs(:debug)
                Config.load({:yaml => {:datadir => "/tmp"}})
                Config.load_backends

                Backend::Yaml_backend.any_instance.expects(:lookup).with("key", {"rspec" => "test"}, nil, nil)

                Backend.lookup("key", "test_%{rspec}", {"rspec" => "test"}, nil, nil).should == "test_test"
            end
        end
    end
end
