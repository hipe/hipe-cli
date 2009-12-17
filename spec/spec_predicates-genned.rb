# bacon spec/spec_predicates-genned.rb
require File.expand_path('../bacon-helper', __FILE__)
require Hipe::Cli::DIR+'/examples/app-it3-predicates.rb'


# You may not want to edit this file.  It was generated from data in "predicates.screenshots"
# by hipe-cli gentest.  If tests are failing here, it means that either 1) the gentest generated
# code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
# your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
# and the tests generated from them.
# So, If the tests are failing here (and assuming gentest isn't broken,) fix your app, get the output you want,
# make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
# an achieve your success that way.  It's really that simple.


describe "Predicates (generated tests)" do

  it "i need to know how many olives you want, juila. (it3-1)" do
    @app = AppIt3.new
    x = @app.cli.commands["order-sandwich"].run(["julia"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your sandwich:
        slice of bread: white
          olives: 3 ct.
        slice of bread: white
      done.
    __HERE__
    x.to_s.should.equal y
  end

  it "enjoy all of your olives (it3-2)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      missing argument: -o
    __HERE__
    x.to_s.should.equal y
  end

  it "you can't have this many olives  (it3-3)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o12"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your sandwich:
        slice of bread: white
          olives: 12 ct.
        slice of bread: white
      done.
    __HERE__
    x.to_s.should.equal y
  end

  it "negative olives don't exist except in cemrel (it3-4)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o13"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      13 is too high a value for num olives.  It can't be above 12
    __HERE__
    x.to_s.should.equal y
  end

  it "this is what they serve you in prison (it3-5)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o-1"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      -1 is too low a value for num olives.  It can't be below 12
    __HERE__
    x.to_s.should.equal y
  end

  it "should work (it3-6)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o0"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your sandwich:
        slice of bread: white
        slice of bread: white
      done.
    __HERE__
    x.to_s.should.equal y
  end
end
