require 'hiera/puppet_logger'

describe Hiera::Puppet_logger do
  it "is not suitable when Puppet is not defined" do
    ensure_puppet_not_defined

    expect(Hiera::Puppet_logger.suitable?).to eq(false)
  end

  it "is suitable when Puppet is defined" do
    ensure_puppet_defined

    expect(Hiera::Puppet_logger.suitable?).to eq(true)
  end

  after :each do
    ensure_puppet_not_defined
  end

  def ensure_puppet_defined
    if !Kernel.const_defined? :Puppet
      Kernel.const_set(:Puppet, "Fake Puppet")
    end
  end

  def ensure_puppet_not_defined
    if Kernel.const_defined? :Puppet
      Kernel.send(:remove_const, :Puppet)
    end
  end
end
