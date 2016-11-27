require 'spec_helper'
require 'tmpdir'

class Hiera
  describe Filecache do
    before do
      @cache = Filecache.new
    end

    def write_file(file, contents)
      File.open(file, 'w') do |f|
        f.write(contents)
      end
    end

    describe "#read" do
      it "reads data from a file" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect(@cache.read(file)).to eq("my data")
        end
      end

      it "rereads data when the file changes" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")
          expect(@cache.read(file)).to eq("my data")

          write_file(file, "changed data")
          expect(@cache.read(file)).to eq("changed data")
        end
      end

      it "uses the provided default when the type does not match the expected type" do
        Hiera.expects(:debug).with(regexp_matches(/String.*not.*Hash, setting defaults/))
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")
          data = @cache.read(file, Hash, { :testing => "hash" }) do |data|
            "a string"
          end

          expect(data).to eq({ :testing => "hash" })
        end
      end

      it "traps any errors from the block and uses the default value" do
        Hiera.expects(:debug).with(regexp_matches(/Reading data.*failed:.*testing error/))
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")
          data = @cache.read(file, Hash, { :testing => "hash" }) do |data|
            raise ArgumentError, "testing error"
          end

          expect(data).to eq({ :testing => "hash" })
        end
      end

      it "raises an error when there is no default given and there is a problem" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect do
            @cache.read(file, Hash) do |data|
              raise ArgumentError, "testing error"
            end
          end.to raise_error(ArgumentError, "testing error")
        end
      end
    end

    describe "#read_file" do
      it "reads data from a file" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect(@cache.read_file(file)).to eq("my data")
        end
      end

      it "sets the encoding to UTF-8 when reading a file" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")
          File.expects(:read).with(file, :encoding => 'BOM|UTF-8')
          @cache.read_file(file)
        end
      end

      it "reads a file with unicode characters" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "☃")

          expect(@cache.read_file(file)).to eq("☃")
        end
      end

      it "rereads data when the file changes" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")
          expect(@cache.read_file(file)).to eq("my data")

          write_file(file, "changed data")
          expect(@cache.read_file(file)).to eq("changed data")
        end
      end

      it "errors when the type does not match the expected type" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect do
            @cache.read_file(file, Hash) do |data|
              "a string"
            end
          end.to raise_error(TypeError)
        end
      end

      it "converts the read data using the block" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect(@cache.read_file(file, Hash) do |data|
            { :data => data }
          end).to eq({ :data => "my data" })
        end
      end

      it "errors when the file does not exist" do
        expect do
          @cache.read_file("/notexist")
        end.to raise_error(Errno::ENOENT)
      end

      it "propogates any errors from the block" do
        Dir.mktmpdir do |dir|
          file = File.join(dir, "testing")
          write_file(file, "my data")

          expect do
            @cache.read_file(file) do |data|
              raise ArgumentError, "testing error"
            end
          end.to raise_error(ArgumentError, "testing error")
        end
      end
    end
  end
end
