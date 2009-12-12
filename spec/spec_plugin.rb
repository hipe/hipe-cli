# bacon spec/plugin_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-cli/sandbox/shelter'

class BasicThree
  include Hipe::Cli::App
  cli.does :quacking
  def quacking
    cli.out << "quack quack"
    cli.out
  end
end
class BasicTwo
  include Hipe::Cli::App
  cli.does :honk
  cli.plugin :quack, BasicThree
  def honk
    cli.out.puts 'honk honk'
    cli.out
  end  
end
class BasicOne
  include Hipe::Cli::App
  cli.plugin :two, BasicTwo
  cli(:out => :buffer_string)
end

describe Hipe::Cli::Plugins do 

  before do
    @app = ShelterPluginyApp.new
    @app.cli.out = Hipe::Io::BufferString.new
  end
     
  it "should allow reflection of registered plugins via prefix name (g1)" do
    ShelterPluginyApp.cli.plugins[:alpha].nil?.should.be.false
    ShelterPluginyApp.cli.plugins[:gamma].nil?.should.be.false
    ShelterPluginyApp.cli.plugins[:namma].nil?.should.be.true
  end
  
  it "should throw an exception when you don't follow the rules for naming plugin files (g2)" do
    lambda { 
      command = @app.cli.commands["file_not_there:blah"]
    }.should.raise Hipe::Cli::Exceptions::PluginNotFound
    lambda { 
      command = @app.cli.commands["class_not_there:blah"]
    }.should.raise Hipe::Cli::Exceptions::PluginNotFound
  end
  
  it "should share output buffers (g3)" do
    aa = BasicOne.new
    out = aa.cli.commands["two:quack:quacking"] << []
    out.should == "quack quack"
  end
  
  it "should determine the right plugin (g4)" do
    command = @app.cli.commands['alpha:shout']
    command.cli.app_class.should == PluginA
    command = @app.cli.commands["alpha:beta:sing"]
    command.cli.app_class.should == PluginB     
    lambda {
      @app.cli.commands['unregistered:xyz']
    }.should.raise(Hipe::Cli::Exceptions::PrefixNotRecognized)
  end

  # @fixme help doesn't work for deeply nested plugins
end
