# bacon spec/help_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/food'

describe  Mexican do
  before do
    class Mexican
      include Hipe::Cli::App
      cli.description = "you will have food as if it's from mexico. here."  
      cli.does :burrito, "this is a delcious burrito"
      cli.out = Hipe::BufferString.new
      def burrito params
        cli.out << "this is your burrito"
      end
      cli.does :taco, "tacos are awesome, everyone loves"
      def burrito params
        cli.out << "awesome taco time"
      end
    end    
  end
  
  it "should display minimal default help with no help activated" do
    mex = Mexican.new    
    mex.cli << shell!('')
    mex.cli >> (str='')
    str.should.match(/^Unexpected command ""\.  Expecting "burrito" or "taco"\n$/i)
  end
  
  
  
end
