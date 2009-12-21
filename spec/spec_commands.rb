# bacon spec/spec_commands.rb
require 'hipe-cli'

class AppC1
   include Hipe::Cli
   cli.does :foo
   def foo; end
end

describe AppC1 do
  it "should know the name and size of its commands (c1)" do
    AppC1.cli.commands.size.should.equal 1
    AppC1.cli.commands.keys.should.equal ["foo"]
    AppC1.cli.commands['foo'].main_name.should.equal :foo
  end
end

class AppC2
  include Hipe::Cli
  cli.does '-b', '--bar[SOME_STUFF]', 'i am a description of bar'
  def bar; end
end

describe AppC2 do
  it "should be able to create optionlike commands (c2)" do
    AppC2.cli.commands.size.should.equal 1
    AppC2.cli.commands.keys.should.equal ["bar"]
    AppC2.cli.commands["bar"].should.be.kind_of Hipe::Cli::OptionyLookingCommand
  end
end

exception = nil
begin
  class AppC3
    include Hipe::Cli
    cli.does '-b', '--bar[SOME_STUFF]', 'i am a description of bar'
    def bar; end
    cli.does 'bar', 'again'
  end
rescue Hipe::Cli::GrammarGrammarException => e
  exception = e
end

describe AppC3 do
  it "should throw an exception on command name conflicts (c3)" do
    exception.should.be.kind_of Hipe::Cli::GrammarGrammarException
  end

  it "should allow long name only (c4)" do
    AppC3.cli.commands.add('--with-desc','desco')
    AppC3.cli.commands.keys.should.equal ['bar', 'with-desc']
    AppC3.cli.commands['with-desc'].description.should.equal 'desco'
  end

  it "should allow short name only (c5)" do
    AppC3.cli.commands.add('-s','short name only')
    AppC3.cli.commands.keys.should.equal ['bar', 'with-desc', 's']
    AppC3.cli.commands['s'].description.should.equal 'short name only'
  end

  it "should raise on bad command name (c6)" do
    e = lambda {
      AppC3.cli.commands.add(777)
    }.should.raise Hipe::Cli::GrammarGrammarException
    e.message.should.match(/bad type for.*name.*Fixnum/i)
  end

end

class AppC7
 include Hipe::Cli
  cli.does :foo
end

describe AppC7 do
  it "should (c7)" do
    lambda{ AppC7.new.cli.run(['foo']) }.should.raise(Hipe::Cli::GrammarGrammarException)
  end
end


