# require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require 'hipe-cli'

class PluginB
  include Hipe::Cli::App
  does :sing, { }
  def sing 
    puts "la la la la la la la"
  end
end

class PluginA 
  include Hipe::Cli::App
  has_cli_plugin 'plugin-b', PluginB
  does :shout, { }
  def shout
    puts "i'm shouting out loud"
  end
end

module SomeModule
  class PluginC; include Hipe::Cli::App; end
end

class MainApp
  include Hipe::Cli::App    
  has_cli_plugin :alpha, PluginA
  has_cli_plugin :beta, PluginB
  has_cli_plugin :gamma, File.dirname(__FILE__)+'/../fakes/some-plugin'
  has_cli_plugin :delta, File.dirname(__FILE__)+'/../fakes/plugind'
  has_cli_plugin :class_not_there, File.dirname(__FILE__)+'/../fakes/some-plugin-empty'
  has_cli_plugin :file_not_there, File.dirname(__FILE__)+'/../not/there'
  does :bark, {}
  def bark
    puts "barking"
  end
end # MainApp


describe "plugin class" do

  it "should == able to add cli commands" do
    PluginA.does?(:shout).should ==  true
  end
  
  it "should register itself when it is defined" do
    Hipe::Cli::AppClasses.has_class?('PluginA').should ==  true
    Hipe::Cli::AppClasses.has_class?(:PluginB).should ==  true    
    Hipe::Cli::AppClasses.has_class?('SomeModule::PluginC').should ==  true    
    Hipe::Cli::AppClasses.has_class?('NotThere::ThisModule').should ==  false        
  end
  
end

describe "main class" do 

  before( :each ) do
    @app = MainApp.new        
  end
  
  it "should allow reflection of commands" do
    MainApp.does?(:bark).should ==  true
    MainApp.does?(:lark).should ==  false    
  end
  
  it "should allow reflection of registered plugins via prefix name" do
    MainApp.has_cli_plugin?(:alpha).should ==  true
    MainApp.has_cli_plugin?('gamma').should ==  true
    MainApp.has_cli_plugin?(:namma).should ==  false        
  end
  
  it "should throw an exception when you don't follow the rules for naming plugin files" do
    lambda { 
      @app.cli_get_plugin_for_command "file_not_there:blah" 
    }.should raise_error Hipe::Cli::PluginNotFoundException
    lambda { 
      @app.cli_get_plugin_for_command "class_not_there:blah"
    }.should raise_error Hipe::Cli::PluginNotFoundException
  end
  
  it "should determine the right plugin" do
    command = "alpha:blah"
    result =  @app.cli_get_plugin_for_command(command).should ==  PluginA
    command.should == 'blah'
    command = "gamma:beta:gamma"
    @app.cli_get_plugin_for_command(command).should ==  SomePlugin 
    command.should ==  'beta:gamma'
    lambda {
      @app.cli_get_plugin_for_command("unregistered:xyz").should ==  false
    }.should raise_error(Hipe::Cli::PluginNotRegisteredException)
    
    @app.cli_get_plugin_for_command('bark').should ==  false
  end
  
  #it "should dispatch a commmand to a plugin" do
  #  command = %w(alpha:plugin-b:sing --ignore='these\ options' here)
  #  buff = ''
  #  def buff.write(s); self << s; end 
  #  old = $stdout
  #  $stdout = buff
  #  @app.cli_run command
  #  $stout = old
  #  puts "here is result: #{str}"
  #  
  #end
  

end












