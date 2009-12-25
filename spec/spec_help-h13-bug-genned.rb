# bacon -n '.*' spec/spec_help-h13-bug-genned.rb
require 'hipe-cli'
require File.join(Hipe::Cli::DIR,'examples/app-h13-bug')
require 'ruby-debug'

# You may not want to edit this file.  It was generated from data in "help-h13-bug.screenshots"
# by hipe-cli gentest on 2009-12-25 03:35.
# If tests are failing here, it means that either 1) the gentest generated
# code that makes tests that fail (it's not supposed to do this), 2) That there is something incorrect in
# your "screenshot" data, or 3) that your app or hipe-cli has changed since the screenshots were taken
# and the tests generated from them.
# So, if the tests are failing here (and assuming gentest isn't broken), fix your app, get the output you want,
# make a screenshot (i.e. copy-paste it into the appropriate file), and re-run gentest, run the generated test,
# an achieve your success that way.  It's really that simple.


describe "Generated test (generated tests)" do

  it "should work (gt-0)" do
    @app = AppH13.new
    x = @app.cli.commands["something"].run(["-h"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    something - description of something

    Usage: h13 something [-h]
        -h
    __HERE__
    x.to_s.chomp.should.equal y
  end

  it "should work (gt-1)" do
    x = @app.cli.commands["something"].run(["-h"])
    y =<<-__HERE__.gsub(/^    /,'').chomp
    something - description of something

    Usage: h13 something [-h]
        -h
    __HERE__
    x.to_s.chomp.should.equal y
  end
end
