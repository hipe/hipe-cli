

class AppOne
  include Hipe::Cli::App
  VERSION = 'x.y.z'
  cli.does '-h --help'
  cli.does '-v --version'
  cli.does :bark, {
    :description => "this is the sound a dog makes",
    :required => [{:name=>:target}, {:name=>:req2}],
    :optionals => [{:name=>:opt1},{:name=>:opt2}],
    :options => { :the_volume => {}, :mood => {} },    
    :splat => {:minimum => 1, :name=>:splat}
  }
  def bark target, req2, opt1, opt2, splat, opts
    out = Hipe::Cli::Io::GoldenHammer.new
    out.puts "barking"
    out[:target] = target
    out
  end
end

shared "a cli app" do
  before do
    @app = AppOne.new
  end  
end

