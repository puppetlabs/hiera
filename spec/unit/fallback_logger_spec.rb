require 'hiera/fallback_logger'

describe Hiera::FallbackLogger do
  before :each do
    InMemoryLogger.reset
    SuitableLogger.reset
  end

  it "delegates #warn to the logger implemenation" do
    logger = Hiera::FallbackLogger.new(InMemoryLogger)

    logger.warn("the message")

    InMemoryLogger.warnings.should == ["the message"]
  end

  it "delegates #debug to the logger implemenation" do
    logger = Hiera::FallbackLogger.new(InMemoryLogger)

    logger.debug("the message")

    InMemoryLogger.debugs.should == ["the message"]
  end

  it "chooses the first logger that is suitable" do
    logger = Hiera::FallbackLogger.new(UnsuitableLogger, SuitableLogger)

    logger.warn("for the suitable logger")

    SuitableLogger.warnings.should include("for the suitable logger")
  end

  it "raises an error if no implementation is suitable" do
    expect do
      Hiera::FallbackLogger.new(UnsuitableLogger)
    end.to raise_error "No suitable logging implementation found."
  end

  it "issues a warning for each implementation that is not suitable" do
    Hiera::FallbackLogger.new(UnsuitableLogger, UnsuitableLogger, SuitableLogger)

    SuitableLogger.warnings.should == [
      "Not using UnsuitableLogger. It does not report itself to be suitable.",
      "Not using UnsuitableLogger. It does not report itself to be suitable."]
  end

  # Preserves log messages in memory
  # and also serves as a "legacy" logger that has no
  # suitable? method
  class InMemoryLogger
    class << self
      attr_accessor :warnings, :debugs
    end

    def self.reset
      self.warnings = []
      self.debugs = []
    end

    def self.warn(message)
      self.warnings << message
    end

    def self.debug(message)
      self.debugs << message
    end
  end

  class UnsuitableLogger
    def self.suitable?
      false
    end
  end

  class SuitableLogger < InMemoryLogger
    def self.suitable?
      true
    end
  end
end
