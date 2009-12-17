# bacon spec/spec_help.rb
require File.expand_path('../bacon-helper', __FILE__)
require Hipe::Cli::DIR+'/examples/app-h7.rb'

describe AppH7, 'after the call to parse_definition' do
#  it "please for gods sake just finally gen a syntax (h19)" do
#    @app = AppH7.new
#    @c = @app.cli.commands['gen_me']
#    debugger
#    @c.run(['-h'])
#    debugger
#    'x'
#  end

  it "should have switches_by_name and switches_by_type ok (h13)" do
    @app = AppH7.new
    c = @app.cli.commands['gen_me']
    c.parse_definition
    c.switches_by_name.size.should.equal 2
    c.switches_by_type.size.should.equal 6
    c.switches_by_type[Hipe::Cli::Switch].size.should.equal 2
  end

  it "elements should reflect via type(h14)" do
    @app = AppH7.new
    @c = @app.cli.commands['gen_me']
    elements = @c.elements
    elements.positionals.size.should.equal 0
    elements.positional.size.should.equal 0
    elements.required.size.should.equal 0
    elements.options.size.should.equal 2
    elements.option.size.should.equal 2
    elements.optionals.size.should.equal 0
  end
  it "positionals size (h15)" do
    @app = AppH7.new
    @c = @app.cli.commands['no_touch']
    @els = @c.elements
    @els.positional.size.should.equal 4
    @els.positionals.size.should.equal 4
  end
  it "requires size (h16)" do
    @els.required.size.should.equal 2
    @els.requireds.size.should.equal 2
  end
  it "options size (h17)" do
    @els.options.size.should.equal 3
    @els.option.size.should.equal 3
  end
  it "optionals size (h18)" do
    @els.optionals.size.should.equal 2
    @els.optional.size.should.equal 2
  end
end

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


describe AppH7, 'larger' do
  it "should display applicaiton help (h7)" do
    @app = AppH7.new
    @app.cli.run(['-h']).should.match(%r{boofhell.*blearg}m)
  end
  it "should display about blearg (h8)" do
    @app.cli.run(['blearg','-h']).should.match(%r{REQ1.*REQ2.*OPT1.*OPT2}m)
  end
  it "pass on valid input (h9)" do
    @app.cli.run(['blearg','-c','clean','flim','flam','shoo-by','doo-by']).should.
     equal %{flim/req2:flam/shoo-by/doo-by/{:cleanliness=>"clean"}"}
  end
  it "complain unexpected (h10)" do
     @app.cli.run(%w(blearg -c clean flim flam shoo-by doo-by blah)).to_s.should.match %r{unexpected}
  end
  it "complain missing (h11)" do
     @app.cli.run(%w(blearg -c clean flim)).to_s.should.match %r{missing}
  end
end

class AppH11; include Hipe::Cli; cli.does('-h','--help'); end

describe AppH11 do
  it "should secrety do the recursive help easter egg that no one will ever find (h12)" do
    x = AppH11.new.cli.commands[:help].run(['-h','--help','-?'] * 10 )
    x.should.match(Regexp.new(Regexp.escape('[...[...[..[.]]]]')))
  end
end
