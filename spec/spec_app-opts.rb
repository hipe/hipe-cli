# bacon spec/spec_app-opts.rb
require 'hipe-cli'
require 'bacon'
require 'ruby-debug'

class AppA1
  include Hipe::Cli
  cli.option('-d','--debug','whether we are in debug mode')
  cli.option('-e','--env','the environment')
  cli.default_command = 'go'
  cli.does('go'){|x|
    option('-b','minus b')
  }
  def go(opts)
    opts.to_hash.inspect
  end
  cli.does('go2'){|x|
    option('-b','minus b')
  }
  def go2(opts)
    opts
  end
end


describe "Application-level options" do

  it "blah (a1)" do
    app = AppA1.new
    app.cli.run(['-d','--env','go','-b']).should.equal '{:debug=>true, :env=>true, :b=>true}'
  end

  it "blah (a2)" do
    app = AppA1.new
    app.cli.run(['-d','--env','go']).should.equal '{:debug=>true, :env=>true}'
  end

end

