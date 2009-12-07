# bacon spec/plugin_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require File.dirname(__FILE__)+'/_shared_one.rb'

describe Hipe::Cli::Plugins do 

  before do
    @app = MyPluginyApp.new
    @app.cli.out = Hipe::BufferString.new
  end
    
  it "should allow reflection of registered plugins via prefix name" do
    MyPluginyApp.cli.plugins[:alpha].should.be.kind_of Hipe::Cli::AppReference
    MyPluginyApp.cli.plugins[:gamma].should.be.kind_of Hipe::Cli::AppReference
    MyPluginyApp.cli.plugins[:namma].should == nil     
  end
  
  it "should throw an exception when you don't follow the rules for naming plugin files" do
    lambda { 
      plugin = @app.cli.plugins << ["file_not_there:blah"]
    }.should.raise Hipe::Cli::PluginNotFoundException
    lambda { 
      plugin = @app.cli.plugins << ["class_not_there:blah"]
    }.should.raise Hipe::Cli::PluginNotFoundException
  end
  
  it "should determine the right plugin" do
    command = "alpha:blah"
    result =  @app.cli.plugins << [command]
    result.should == PluginA
    command.should == 'blah'
    
    command = "gamma:beta:gamma"
    result = @app.cli.plugins << [command]
    result.should ==  SomePlugin     
    command.should ==  'beta:gamma'
    lambda {
      @app.cli.plugins << ["unregistered:xyz"]
    }.should.raise(Hipe::Cli::PrefixNotRecognizedException)
  end
  
  it "should return nil for commands that don't have prefixes" do
    (@app.cli.plugins << shell!("on my face")).should == nil
  end
  
  it "should dispatch a commmand to a plugin" do
    @app.cli.plugins.delete(:delta) # careful -- it's a bad one.
    @app.cli.plugins.delete(:class_not_there)
    @app.cli.plugins.delete(:file_not_there)    
    command = shell! %x{alpha:plugin-b:sing --ignore='these options' here}
    @app.cli << command
    @app.cli >> (output='')
    output.should == "la la la la la la la"
  end
end
