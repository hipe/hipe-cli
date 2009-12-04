# bacon spec/basics_spec.rb 
require File.dirname(__FILE__)+'/test-strap.rb'

describe Hipe::Cli::App,"basics" do
  behaves_like "a cli app"
  
  it "should reflect correctly on nonexistent commands" do    
    @app.cli.commands[:not_there].should.equal nil
  end
  
  it "should reflect correctly on existent commands" do
    @app.cli.commands[:bark].should.be.kind_of Hipe::Cli::Command
  end
end

describe Hipe::Cli::Request do
  behaves_like "a cli app"
  
  it "should parse an empty string, possibly with errors" do
    request = @app.cli.commands[:bark] << shell!('')
    request.should.be.kind_of Hipe::Cli::Request
    request.should.equal Hipe::Cli::Request[
      :options=>{}, :optionals=>{}, :required=>{}, :splat=>[], :extra=>{}      
    ]
  end
   
  it "should parse required, optionals and splat correctly" do
    request = @app.cli.commands[:bark] << shell!('one two three four five six seven')
    request.should == Hipe::Cli::Request[
      :options=>{},
      :required=>{:target=>'one', :req2=>'two'},
      :optionals=>{:optl1=>'three',:optl2=>'four'},
      :splat=>['five','six','seven'],
      :extra=>{}                                                    
    ]
  end
  
  it "should parse extra arguments correctly with empty grammar" do
    command = Hipe::Cli::Command.new(:whatever, {})
    request = command << shell!('one two three')
    request.should == Hipe::Cli::Request[
      :options=>{},:required=>{},:optionals=>{},:splat=>[], 
      :extra=>{0=>'one',1=>'two',2=>'three'}
    ]
  end
  

  it "should parse options correctly" do
    command = Hipe::Cli::Command.new(:whatever, {
      :options=>{
        '-x --opt1' => {},
        '-o --opt2' =>{:type=>:increment},
        '-y --opt3' => {},
        '-z --opt4' => {:type=>:boolean}
      }
    })
    args = shell!('--opt1=loud -ooooo --opt4')

    request = command << args
    
    request.should == Hipe::Cli::Request[
      :options=>{:opt1=>'loud', :opt2=>5, :opt4=>true},
      :required=>{},:optionals=>{},:splat=>[], :extra=>{}
    ]
  end  

end