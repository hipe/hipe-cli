# bacon spec/FOCUS.rb
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/shelter'


describe "blah" do

  before do
    @app = MyPluginyApp.new
    @app.cli.out = Hipe::BufferString.new
  end

  
  it "should dispatch a commmand to a plugin (g5)" do

    @app.cli.plugins.delete(:delta) # careful -- it's a bad one.
    @app.cli.plugins.delete(:class_not_there)
    @app.cli.plugins.delete(:file_not_there)    
    @app.cli << ['alpha:beta:sing']
    @app.cli >> (output='')
    
    output.should == "la la la la la la la\n"
  end
end
