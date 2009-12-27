# bacon -n '.*' spec/spec_predicates-first-genned.rb
require 'examples/app-it3-predicates'


# You may not want to edit this file.  It was generated from data in "predicates-first.screenshots"
# by hipe-cli gentest on 2009-12-26 23:59.
# If tests are failing here, it means that either 1) the gentest generated
# code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
# your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
# and the tests generated from them.
# So, if the tests are failing here (and assuming gentest isn't broken), fix your app, get the output you want,
# make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
# an achieve your success that way.  It's really that simple.


describe "Generated test (generated tests)" do

  it "# you get a default sandwich this way.  enjoy your olives (pf-0)" do
    @app = AppIt3.new
    x = @app.cli.commands["order-sandwich"].run(["julia"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    your sandwich:
      slice of bread: white
        olives: 3 ct.
      slice of bread: white
    done.
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# i need to know how many olives you want, juila. (pf-1)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    missing argument: -o
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# enjoy all of your olives (pf-2)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o12"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    your sandwich:
      slice of bread: white
        olives: 12 ct.
      slice of bread: white
    done.
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# you can't have this many olives  (pf-3)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o13"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    13 is too high a value for num olives.  It can't be above 12
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# negative olives don't exist except in cemrel (pf-4)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o-1"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    -1 is too low a value for num olives.  It can't be below 12
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# this is what they serve you in prison (pf-5)" do
    x = @app.cli.commands["order-sandwich"].run(["julia", "-o0"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    your sandwich:
      slice of bread: white
      slice of bread: white
    done.
    __HERE__
    x.to_s.chomp.should.equal y
  end
end
