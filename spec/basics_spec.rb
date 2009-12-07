# bacon spec/basics_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require File.dirname(__FILE__)+'/helpers/shared_one.rb'

Oh = OrderedHash

describe Hipe::Cli::App,"basics" do

  it "should reflect correctly on nonexistent commands" do
    @app = MainApp.new    
    @app.cli.commands[:not_there].should.equal nil
  end
  
  it "should reflect correctly on existent commands" do
    @app.cli.commands[:bark].should.be.kind_of Hipe::Cli::Command
  end
   
  it "should parse required, optionals and splat correctly" do
    request = @app.cli.commands[:bark] << shell!('one two three four five six seven')
    request.cli_tree.should == Hipe::Cli::Request[
      :options=>Oh[],
      :required=>Oh[:target,'one', :req2,'two'],
      :optionals=>Oh[:optl1,'three',:optl2,'four'],
      :splat=>['five','six','seven'],
      :extra=>Oh[]
    ]
  end
  
  it "should parse extra arguments correctly with empty grammar" do
    command = Hipe::Cli::Command.new(:whatever, {})
    request = command << shell!('one two three')
    request.cli_tree.should == Hipe::Cli::Request[
      :options=>Oh[],:required=>Oh[],:optionals=>Oh[],:splat=>[], 
      :extra=>{0=>'one',1=>'two',2=>'three'}
    ]
  end
  
  it "should parse options correctly" do
    command = Hipe::Cli::Command.new(:whatever, {
      :options => {
        '-x --opt1' => {},
        '-o --opt2' => {:type=>:increment},
        '-y --opt3' => {},
        '-z --opt4' => {:type=>:boolean}
      }
    })
    args = shell!('--opt1=loud -ooooo --opt4')
    request = command << args
  
    request.cli_tree.should == Hipe::Cli::Request[
      :options=>Oh[:opt1,'loud', :opt2,5, :opt4,true],
      :required=>Oh[],:optionals=>Oh[],:splat=>[], :extra=>Oh[]
    ]
  end
  
  it "should parse an empty string, possibly with errors" do
    request = @app.cli.commands[:bark] << shell!('')
    request.should.be.kind_of Hipe::Cli::Request
    target = Hipe::Cli::Request[:options,Oh[], :required,Oh[], :optionals,Oh[], :splat,[], :extra,Oh[]]
    request.cli_tree.should.equal target
  end
  
  it "should parse optionals" do
    request = @app.cli.commands[:bark] << shell!('alpha beta gamma delta')
    tree = request.cli_tree
    tree.should.be.kind_of Hash
    target = Hipe::Cli::Request[:options,Oh[], :required,Oh[
        :target, 'alpha', :req2, 'beta'
      ], :optionals,Oh[
      :optl1, 'gamma', :optl2, 'delta'
    ], :splat,[], :extra,Oh[]]
    tree.should.equal target
  end
end