# bacon spec/spec_optparsey.rb
require File.expand_path('../bacon-helper', __FILE__)
#require Hipe::Cli::DIR+'/examples/app-op1.rb'

class AppOp1
  include Hipe::Cli
  cli.does(:sing, "sweet sweet sounds") do
    option('-d', '--decibles[BLAH]') do |x|
      %{implementation says "#{x}"}
    end
  end
  def sing(opts)
    %{decibles is "#{opts[:decibles]}"}
  end
end

describe AppOp1 do
  it "should actually pipe an option thru optparse yay! (op1)" do
    response = AppOp1.new.cli.commands['sing'].run ['-d27']
    response.should.equal %{decibles is "implementation says "27""}
  end

  it "will always take multiple arguments for now (opt2)" do
    response = AppOp1.new.cli.commands['sing'].run ['-d27', '-d26']
    response.should.equal %{decibles is "implementation says "27"implementation says "26""}
  end

end
