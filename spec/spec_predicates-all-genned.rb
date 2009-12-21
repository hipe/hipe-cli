# bacon -n '(.*)' spec/spec_predicates-all-genned.rb
require 'hipe-cli'
require Hipe::Cli::DIR+'/examples/app-it4-all-builtin-predicates.rb'
require 'ruby-debug'


# You may not want to edit this file.  It was generated from data in "predicates-all.screenshots"
# by hipe-cli gentest.  If tests are failing here, it means that either 1) the gentest generated
# code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
# your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
# and the tests generated from them.
# So, If the tests are failing here (and assuming gentest isn't broken,) fix your app, get the output you want,
# make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
# an achieve your success that way.  It's really that simple.


describe "All builtin predicates (generated tests)" do

  it "regexp fail (it4-1)" do
    @app = AppIt4.new
    x = @app.cli.commands["go"].run([])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {}
    __HERE__
    x.to_s.should.equal y
  end

  it "regexp succ (it4-2)" do
    x = @app.cli.commands["go"].run(["--against-regexp", "fail"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      against regexp "fail" does not match the correct pattern
    __HERE__
    x.to_s.should.equal y
  end

  it "integer fail (it4-3)" do
    x = @app.cli.commands["go"].run(["--against-regexp", "abc123"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:against_regexp=>["abc", "123"]}
    __HERE__
    x.to_s.should.equal y
  end

  it "integer succ (it4-4)" do
    x = @app.cli.commands["go"].run(["--must-be-integer", "abc"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      Your value for must be integer ("abc") does not appear to be an integer
    __HERE__
    x.to_s.should.equal y
  end

  it "float fail (it4-5)" do
    @app = AppIt4.new
    x = @app.cli.commands["go"].run(["--must-be-integer", "123"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_integer=>123}
    __HERE__
    x.to_s.should.equal y
  end

  it "float succ zero point zero (it4-6)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "abc"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      Your value for must be float ("abc") does not appear to be a float
    __HERE__
    x.to_s.should.equal y
  end

  it "float succ neg zero (it4-7)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "0.0"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_float=>0.0}
    __HERE__
    x.to_s.should.equal y
  end

  it "float succ zero (it4-8)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "-0.0"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_float=>-0.0}
    __HERE__
    x.to_s.should.equal y
  end

  it "float succ one (it4-9)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "0"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_float=>0.0}
    __HERE__
    x.to_s.should.equal y
  end

  it "float succ neg one (it4-10)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "1"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_float=>1.0}
    __HERE__
    x.to_s.should.equal y
  end

  it "file must exist succ (it4-11)" do
    x = @app.cli.commands["go"].run(["--must-be-float", "-1"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_be_float=>-1.0}
    __HERE__
    x.to_s.should.equal y
  end

  it "file must exist fail (it4-12)" do
    x = @app.cli.commands["go"].run(["--must-exist", "spec/read-only/exists.txt"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_exist=>"spec/read-only/exists.txt"}
    __HERE__
    x.to_s.should.equal y
  end

  it "file must not exit succ (it4-13)" do
    x = @app.cli.commands["go"].run(["--must-exist", "spec/read-only/not-exists.txt"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      File not found: "spec/read-only/not-exists.txt"
    __HERE__
    x.to_s.should.equal y
  end

  it "file must not exit fail (it4-14)" do
    x = @app.cli.commands["go"].run(["--must-not-exist", "spec/read-only/exists.txt"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      File must not exist: "spec/read-only/exists.txt"
    __HERE__
    x.to_s.should.equal y
  end

  it "should work (it4-15)" do
    x = @app.cli.commands["go"].run(["--must-not-exist", "spec/read-only/not-exists.txt"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your opts: {:must_not_exist=>"spec/read-only/not-exists.txt"}
    __HERE__
    x.to_s.should.equal y
  end
end
