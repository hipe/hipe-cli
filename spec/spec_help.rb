# bacon spec/spec_help.rb
require File.expand_path('../bacon-helper', __FILE__)


class AppH1
  include Hipe::Cli
end

describe AppH1, 'the empty application' do
  it "should be satisfied on empty input. (h1)" do
    AppH1.new.cli.run([]).should.equal "done.\n"
  end
  it "should complain on any input (h2)" do
    AppH1.new.cli.run(['blah']).should.match %r{Unexpected command "blah"\.  Expecting nothing.}
  end

end

class AppH3
  include Hipe::Cli
  cli.does :blah
end

class AppH5
  include Hipe::Cli
  cli.does :blah; cli.does :bleh
end

class AppH6
  include Hipe::Cli
  cli.does :blah; cli.does :bleh; cli.does :blearg
end

describe AppH3, 'with one command' do
  it "should complain about the empty command (h3)" do
    AppH3.new.cli.run([]).should.match %r{Unexpected command ""\.  Expecting "blah"}
  end
  it "should complain on any input (h4)" do
    AppH3.new.cli.run(['bling']).should.match %r{Unexpected command "bling"\.  Expecting "blah"}
  end
end

describe AppH5, 'two fish' do
  it "should 'or' (h5)" do
    AppH5.new.cli.run([]).should.match %r{Unexpected command ""\.  Expecting "blah" or "bleh"}
  end
  it "oxford comma (h6)" do
    AppH6.new.cli.run([]).should.match %r{Unexpected command ""\.  Expecting "blah", "bleh" or "blearg"}
  end
end

require Hipe::Cli::DIR+'/examples/app-h7.rb'
describe AppH7, 'larger' do
  it "should display applicaiton help (h7)" do
    @app = AppH7.new
    @app.cli.run(['-h']).should.match(%r{boofhell.*blearg}m)
  end
  it "should display about blearg (h8)" do
    @app.cli.run(['blearg','-h']).should.match(%r{REQ1.*REQ2.*OPT1.*OPT2}m)
  end
  it "parses (h9)" do
    @app.cli.run(['blearg','-c','clean','flim','flam','shoo-by','doo-by']).should.
     equal %{flim/req2:flam/shoo-by/doo-by/{:cleanliness=>"clean"}"}
  end
  it "this (h10)" do
     @app.cli.run(%w(blearg -c clean flim flam shoo-by doo-by blah)).should.match %r{unexpected}
  end
  it "this (h11)" do
     @app.cli.run(%w(blearg -c clean flim)).should.match %r{missing}
  end
end
