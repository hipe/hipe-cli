# bacon -n '.*' spec/writable-tmp/spec_my-genned-spec.rb
require 'hipe-cli'
require File.join(Hipe::Cli::DIR,'examples/app-it3-predicates')


# You may not want to edit this file.  It was generated from data in "gentest-multi-line-json.screenshots"
# by bacon gentest.  If tests are failing here, it means that either 1) the gentest generated
# code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
# your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
# and the tests generated from them.
# So, if the tests are failing here (and assuming gentest isn't broken), fix your app, get the output you want,
# make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
# an achieve your success that way.  It's really that simple.


describe "Generated test (generated tests)" do

  it "# forgot name (gt-0)" do
    @app = AppIt3.new 
    x = @app.cli.run(["order-sandwich", "-t", "mayonaise"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      there is one missing required argument: name
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "# ok (gt-1)" do
    x = @app.cli.run(["order-sandwich", "-t", "mayonaise", "sarah"])
    y =<<-__HERE__.gsub(/^      /,'').chomp
      your sandwich:
        slice of bread: white
          topping: mayonaise
          olives: 3 ct.
        slice of bread: white
      done.
    __HERE__
    x.to_s.chomp.should.equal y
  end
end
