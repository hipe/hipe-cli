# bacon spec/spec_app-opts.rb
require File.expand_path('../bacon-helper', __FILE__)

class AppA1
  include Hipe::Cli
  cli.option('-d','--debug','whether we are in debug mode')
  cli.option('-e','--env','the environment')
  cli.default_command = 'go'
  cli.does('go'){|x|
    option('-b','minus b')
  }
  def go(opts)
    opts.inspect
  end
end


describe "Application-level options" do
  it "blah (a1)" do
    app = AppA1.new
    app.cli.run(['-d','--env','go','-b']).should.equal '{:debug=>true, :env=>true, :b=>true}'
  end

  #it "should allow for help and version this way -- the default command et." do
  #end
end

