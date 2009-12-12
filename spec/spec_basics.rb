# bacon spec/spec_basics.rb 
require 'hipe-core/struct-diff'
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require File.dirname(__FILE__)+'/helpers/shared_one.rb'

Oh = OrderedHash

describe Hipe::Cli::App,"basics" do
  it "should reflect correctly on nonexistent commands (b1)" do
    @app = AppOne.new    
    @app.cli.commands[:not_there].should.equal nil
  end
  
  it "should reflect correctly on existent commands (b2)" do
    @app.cli.commands[:bark].should.be.kind_of Hipe::Cli::Command
  end
   
  it "should parse required, optionals and splat correctly (b3)" do
    request = @app.cli.commands[:bark].prepare_request %w(one two three four five six seven)
    have = request.cli_tree
    want = Hipe::Cli::OrderedRequest[
      :options=>Oh[],
      :required=>Oh[:target,'one', :req2,'two'],
      :optionals=>Oh[:opt1,'three',:opt2,'four'],
      :splat=>{:splat=>["five", "six", "seven"]},
      :extra=>Oh[]
    ]
    diff = Hipe::StructDiff.diff(have, want)
    diff.summarize.should == '(none)'
  end

  it "should parse extra arguments correctly with empty grammar (b4)" do
    command = Hipe::Cli::Command.new(nil, {:name=>'x'})
    request = command.prepare_request %w(one two three)
    request.cli_tree.should == Hipe::Cli::OrderedRequest[
      :options=>Oh[],:required=>Oh[],:optionals=>Oh[],:splat=>{}, 
      :extra=>{0=>'one',1=>'two',2=>'three'}
    ]
  end
  
  it "should parse options correctly (b5)" do
    command = Hipe::Cli::Command.new(nil,{
      :name => 'blah',
      :options => {
        '-x --opt1' => {},
        '-o --opt2' => {:type=>:increment},
        '-y --opt3' => {},
        '-z --opt4' => {:type=>:boolean}
      }
    })
    args = ["--opt1=loud", "-ooooo", "--opt4"]
    request = command.prepare_request args
  
    request.cli_tree.should == Hipe::Cli::OrderedRequest[
      :options=>Oh[:opt1,'loud', :opt2,5, :opt4,true],
      :required=>Oh[],:optionals=>Oh[],:splat=>{}, :extra=>Oh[]
    ]
  end
  
  it "should parse an empty string, possibly with errors (b6)" do
    request = @app.cli.commands[:bark].prepare_request []
    request.should.be.kind_of Hipe::Cli::OrderedRequest
    target = Hipe::Cli::OrderedRequest[:options,Oh[], :required,Oh[], :optionals,Oh[], :splat,{}, :extra,Oh[]]
    request.cli_tree.should.equal target
  end
  
  it "should parse optionals (b7)" do
    request = @app.cli.commands[:bark].prepare_request %w(alpha beta gamma delta)
    have = request.cli_tree
    have.should.be.kind_of Hash
    want = Hipe::Cli::OrderedRequest[:options,Oh[], :required,Oh[
        :target, 'alpha', :req2, 'beta'
      ], :optionals,Oh[
      :opt1, 'gamma', :opt2, 'delta'
    ], :splat,{}, :extra,Oh[]]
    diff = Hipe::StructDiff.diff(want, have).summarize
    diff.should == '(none)'
  end
end