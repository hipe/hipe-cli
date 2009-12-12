require File.expand_path('../bacon-helper', __FILE__)

describe Hipe::Cli do
  it "should have loaded with the correct version (f1)" do
    Hipe::Cli::VERSION.should == '0.0.3'
  end
end
