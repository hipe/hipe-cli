# bacon spec/spec_grammar-grammar.rb
#require Hipe::Cli::DIR+'/examples/app-op1.rb'

class AppGg1
  include Hipe::Cli
  cli.does(:whatever1) do
    required :blah
    option('-a', '--Aaa') {|x| 'xyz'}
  end
  def whatever1(*args); 'whatever1' end

  cli.does(:whatever2) do
    optional '--blah'
    required :blah
  end
  def whatever2(*args); 'whatever2' end

  cli.does(:whatever3) do
    optional('--blah')
    splat('blah')
  end
  def whatever3(*args); 'whatever3' end

  cli.does(:whatever4) do
    splat('blah')
    optional('--blah')
  end
  def whatever4(*args); 'whatever4' end

  cli.does(:whatever5) do
    splat('blah')
    splat('blah2')
  end
  def whatever5(*args); 'whatever5' end
end

describe AppGg1, "at run time" do
  it "should enforce that options come before required (gg1)" do
    @app = AppGg1.new
    e = lambda{ @app.cli.commands[:whatever1].run(['']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(/option.*(?:cannot|shouldn't|should not) (?:come|appear|follow) after.*required/i)
  end

  it "should enforce that required come before optional (gg2)" do
    e = lambda{ @app.cli.commands[:whatever2].run(['']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(/required.*(?:cannot|shouldn't|should not) (?:come|appear|follow) after optional/i)
  end

  it "should enforce that splat does not come after optional (gg3)" do
    e = lambda{ @app.cli.commands[:whatever3].run(['']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(/splat.*(?:cannot|shouldn't|should not) (?:come|appear|follow) after optional/i)
  end

  it "should enforce that optional does not come after splat (gg4)" do
    e = lambda{ @app.cli.commands[:whatever4].run(['']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(/optional.*(?:cannot|shouldn't|should not) (?:come|appear|follow) after.*splat/i)
  end

  it "should enforce that splat cannot come after splat (gg5)" do
    e = lambda{ @app.cli.commands[:whatever5].run(['']) }.should.raise(Hipe::Cli::GrammarGrammarException)
    e.message.should.match(/splat.*(?:cannot|shouldn't|should not) (?:come|appear|follow) after.*splat/i)
  end
end
