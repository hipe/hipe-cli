# bacon spec/spec_basics.rb

describe Hipe::Cli do
  it "should have loaded with the correct version (b1)" do
    Hipe::Cli::VERSION.should == '0.0.9'
  end
end

class App2
  include Hipe::Cli
end

describe Hipe::Cli do
  it "should allow a class to mix it in, and give the cli object (b2)" do
    App2.cli.should.be.kind_of Hipe::Cli::Cli
  end
end

class App3
  VERSION = '3'
  include Hipe::Cli
end

describe App3 do
  it "should not be getting the constants from Hipe Cli when it includes it (b3)" do
    App3::VERSION.should == '3'
  end

  it "should have an instance of cli different fomr the other class (b4)" do
    App3.cli.should.not == App2.cli
  end

  it "should be able to create instances that have a cli (b5)" do
    @app3 = App3.new
    @app3.cli.should.be.kind_of Hipe::Cli::Cli
  end

  it "should have instances with different cli instances than the class (b6)" do
    (@app3.cli.equal? App3.cli).should == false
    (@app3.cli.equal? @app3.cli).should == true
  end
end
