require 'hipe-cli'

class TweedleDum
  include Hipe::Cli::App
  #bark --dog-name=NAME --dog-age=AGE --extra-dog-info={weight:120kg} IN_FILE OUT_FILE [OUT_FILE[...]]
  does :bark, {
    :options => { 
      :dog_age =>  {:it=>(0..120)},
      :dog_name => {:it=>['must be alpha numeric',/^[[:alnum:]]+/]},
      :extra_dog_info => {:it=>:is_jsonesque }
    },
    :required => [{:name=>:OUT_FILE, :it=>[:must_not_exist,:gets_opened]}],
    :splat => {:name=>:IN_FILES, :minimum => 1,:they =>[:must_exist] }
  }
  def bark
    puts "bow wow"
  end
end

class TweedleDee
  include Hipe::Cli::App
  has_cli_plugin :dog, TweedleDum
end

def get_argv str
  x =`ruby #{File.dirname(__FILE__)}/argv.rb #{str}`
  Marshal.load x
end

describe "command validation" do
  
  before( :each ) do 
    @app = TweedleDee.new
  end
  
  it "should be able to get a parsed argv from the shell" do 
    argv = get_argv 'dog:bark --dog-name="sammy davis" --dog-age=22 --extra-dog-info={weight:120kg} '+
     'outfile dummy-file.txt dummy-file-2.txt'

    @app.cli_command(argv).should == Hipe::Cli::Command[
      {:optionals=>{},
       :extra=>{},
       :splat=>["dummy-file.txt", "dummy-file-2.txt"],
       :options=>
        {:dog_age=>"22",
         :dog_name=>"sammy davis",
         :extra_dog_info=>"{weight:120kg}"},
       :required=>{:OUT_FILE=>"outfile"}}        
    ]
  end
end