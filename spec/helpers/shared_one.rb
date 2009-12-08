

class AppOne
  include Hipe::Cli::App
  VERSION = 'x.y.z'
  cli.does '-h --help'
  cli.does '-v --version'
  cli.does :bark, {
    :description => "this is the sound a dog makes",
    :options => { :the_volume => {}, :mood => {} },
    :required => [{:name=>'target'}, {:name=>'req2'}],
    :optionals => [{:name=>'optl1'},{:name=>'optl2'}],
    :splat => {:minimum => 1, :name=>'splat'}
  }
  def bark request
    @out.puts "barking"
  end
end

shared "a cli app" do
  before do
    @app = AppOne.new
  end  
end

