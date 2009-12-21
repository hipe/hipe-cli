# bacon spec/spec_defaults.rb
require Hipe::Cli::DIR+'/examples/app-d1-defaults.rb'

describe AppD1,'defaults' do

  it "wonderhot (d0)" do
    @app = AppD1.new
    str = @app.cli.run(['rhythmic-gymnastics','--long-one=i\'m long','-oTHING', '--last-one=123'])
    str.should.equal %[apparatus is "round ball" and opts are: {:long_one=>"i'm long", :o=>"THING", :last_one=>"123"}]
  end

  it "should complain on attempt to add defaults to required argument (d1)" do
    lambda{
      @app.cli.run(['jump'])
    }.should.raise(Hipe::Cli::GrammarGrammarException, %{required arguments can't have defaults ("blah")})
  end

  it "with no codeblocks, it should populate the defaults for opt and optional (d2)" do
    str = @app.cli.run(['swim','10minutes'])
    str.should.equal %{dur:10minutes, ft:100ft, depth:10ft}
  end

  it "with a codeblock it should pass thru the provided info (d3)" do
    str = @app.cli.run(['pole-vault', '999ft'])
    str.should.equal %{pv height: this many: 999ft}
  end

  it "with a codeblock it should pass thru the default info (d4)" do
    str = @app.cli.run(['pole-vault'])
    str.should.equal %{pv height: this many: 1000feet}
  end

  it "should still allow that option list thingy, and still work (d5)" do
    str = @app.cli.run(['rhythmic-gymnastics'])
    str.should.equal %[apparatus is "round ball" and opts are: {:long_one=>"longval", :o=>"just one", :last_one=>"last1"}]
  end

it "should pass thru again (d6)" do
    @app = AppD1.new
    res = @app.cli.run(['rhythmic-gymnastics','wrong'])
    res.to_s.should.match %r{invalid value for apparatus: "wrong"}
  end

end

class  AppD7
  include Hipe::Cli
  cli.does(:blah) do
    option('--needs-arg-here',:default => 'never see it')
  end
  cli.does('blah-blah') do
    required('one')
    required('two')
  end
  def blah_blah(only_one)
  end
  cli.does('bling') do
    option('-a LETTER',['b','c','d'])
  end
end

describe AppD7, "fallatious" do
  it "should require options with args for default (d7)" do
    @app = AppD7.new
    e = lambda{ @app.cli.run(['blah'])}.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match %r{needs_arg_here}
  end
  it "should require that the implementing thing be the same signature (d8)" do
    e = lambda{ @app.cli.run(['blah-blah','one','two'])}.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match %r{must take 2 arguments}
  end
  it "single letter list thing (d9)" do
    @app = AppD7.new
    msg = @app.cli.run(['bling','-a=e'])
    msg.to_s.should.match %r{invalid argument}
  end
end
