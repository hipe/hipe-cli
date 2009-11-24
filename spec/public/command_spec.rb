require 'hipe-cli'

class MainApp
  include Hipe::Cli::App
  does :bark, {
    :options => { :opt1 => {}, :opt2 => {} },
    :required => [{:name=>'req1'}, {:name=>'req2'}],
    :optionals => [{:name=>'optl1'},{:name=>'optl2'}],
    :splat => {:minimum => 1}
  }
  def bark
    puts "barking"
  end
end # MainApp


describe "command grammar" do
  before(:each) do
    @app = MainApp.new
  end
  
  it "should be determined correctly" do
    @app.class.cli_command_grammar(:not_there).should equal nil
    grammar = @app.class.cli_command_grammar :bark
    grammar.should respond_to :parse
  end
  
  it "should parse an empty input string correctly" do
    grammar = @app.class.cli_command_grammar(:bark)
    command = grammar.parse([])
    command.should == Hipe::Cli::Command[
      :options=>{}, :optionals=>{}, :required=>{}, :splat=>[], :extra=>{}
    ]
  end
  
  it "should parse required, optionals and splat correctly" do
    grammar = @app.class.cli_command_grammar(:bark)
    command = grammar.parse(%w(one two three four five six seven))
    command.should == Hipe::Cli::Command[
      :options=>{},
      :required=>{:req1=>'one', :req2=>'two'},
      :optionals=>{:optl1=>'three',:optl2=>'four'},
      :splat=>['five','six','seven'], 
      :extra=>{}
    ]    
  end
  
  it "should handle extra arguments correctly with empty grammar" do
    g = Hipe::Cli::CommandGrammar.new(:whatever, {} )
    command = g.parse(%w(one two three))
    command.should == Hipe::Cli::Command[
      :options=>{},:required=>{},:optionals=>{},:splat=>[], 
      :extra=>{0=>'one',1=>'two',2=>'three'}
    ]
  end
  
  it "should parse options correctly" do
    g = Hipe::Cli::CommandGrammar.new(:whatever, {
      :options=>{
        :opt1 => {},
        :opt2 => {:getopt_letter=>'b', :getopt_type => Getopt::INCREMENT},
        :opt3 => {},
        :opt4 => {:getopt_type=>Getopt::BOOLEAN}
      }
    } )
    command = g.parse(%w(--opt1=one -bbbbb --opt4))
    command.should == Hipe::Cli::Command[
      :options=>{:opt1=>'one', :opt2=>5, :opt4=>true},
      :required=>{},:optionals=>{},:splat=>[], :extra=>{}
    ]
  end
  
end