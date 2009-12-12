# bacon spec/help_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/food'

class MexMin
  include Hipe::Cli::App
  cli.does :taco; 
  def taco; end  
  cli.does :burrito;
  def burrito; end
end

class MexV
  include Hipe::Cli::App
  VERSION = 'quatro.cinco.seis'
  cli.does '-v --version'
end

describe MexMin do
  it "should generate expecting from the outset. (h1)" do
    @mex = MexMin.new
    x = @mex.cli.expecting
    x.should == ['taco','burrito']
  end
  
  it "should display minimal default help with no help activated (h2)" do
    cli = MexMin.new.cli(:out => :buffer_string)
    out = cli << []
    out.should.match(/^Unexpected command ""\.  Expecting "taco" or "burrito"\n$/i)
  end
  
  it "wtf version (h3)" do
    cli = MexV.new.cli(:out => :buffer_string)
    c = cli.commands[:version] << ['--bare']
    c.should == 'quatro.cinco.seis'
  end
  
  
end
