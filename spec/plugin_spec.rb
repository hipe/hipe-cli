# bacon spec/plugin_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/shelter'

describe Hipe::Cli::Plugins do 

  before do
    @app = MyPluginyApp.new
    @app.cli.out = Hipe::BufferString.new
  end
     
  it "should allow reflection of registered plugins via prefix name (g1)" do
    MyPluginyApp.cli.plugins[:alpha].should.be.kind_of Hipe::Cli::AppReference
    MyPluginyApp.cli.plugins[:gamma].should.be.kind_of Hipe::Cli::AppReference
    MyPluginyApp.cli.plugins[:namma].should == nil     
  end
  
  it "should throw an exception when you don't follow the rules for naming plugin files (g2)" do
    lambda { 
      plugin = @app.cli.plugins.plugin_for_argv ["file_not_there:blah"]
    }.should.raise Hipe::Cli::PluginNotFoundException
    lambda { 
      plugin = @app.cli.plugins.plugin_for_argv ["class_not_there:blah"]
    }.should.raise Hipe::Cli::PluginNotFoundException
  end
  
  
  it "should dispatch a commmand to a plugin (g5)" do

    @app.cli.plugins.delete(:delta) # careful -- it's a bad one.
    @app.cli.plugins.delete(:class_not_there)
    @app.cli.plugins.delete(:file_not_there)    
    @app.cli << ['alpha:beta:sing']
    @app.cli >> (output='')
    
    output.should == "la la la la la la la\n"
  end  
  
  
  it "should determine the right plugin (g3)" do
    argv = ["alpha:blah"]
    result =  @app.cli.plugins.plugin_for_argv argv
    result.class.should == PluginA
    argv[0].should == 'blah'
     
    argv = ["gamma:beta:gamma"]
    result = @app.cli.plugins.plugin_for_argv argv
    result.class.should ==  SomePlugin     
    argv[0].should ==  'beta:gamma'
    lambda {
      @app.cli.plugins.plugin_for_argv ['unregistered:xyz']
    }.should.raise(Hipe::Cli::PrefixNotRecognizedException)
  end
  

  
  it "should return nil for commands that don't have prefixes (g4)" do
    (@app.cli.plugins.plugin_for_argv(shell!("on my face"))).should == nil
  end


  # @fixme help doesn't work for deeply nested plugins
end
