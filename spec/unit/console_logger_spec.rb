require 'spec_helper'

class Hiera
  describe Console_logger do
    describe "#warn" do
      it "should warn to STDERR" do
        STDERR.expects(:puts).with("WARN: 0: foo")
        Time.expects(:now).returns(0)
        Console_logger.warn("foo")
      end

      it "should debug to STDERR" do
        STDERR.expects(:puts).with("DEBUG: 0: foo")
        Time.expects(:now).returns(0)
        Console_logger.debug("foo")
      end
    end
  end
end
