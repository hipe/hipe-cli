#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'

class AppH7
  include Hipe::Cli
  cli.does("boof" 'hello'){}
  def boof; end;
  cli.does('-r','rare to have such a command')
  cli.does("-h", "--help", "display this screen")
  cli.does(:gen_me) do
    option('-h',&help)
    option('-o','one option')
  end
  def gen_me(opts)
    'blif fla'
  end
  cli.does("blif-blaff","almost back to where we started in version 0.0.3.  What a ridiculous version that was.") {}
  def blif_blaff; end;
  cli.does("-v", "--version", "version of this app")
  cli.does(:blearg, "this method does your laundry" ) do
    option('-c','--cleanliness HOW_CLEAN', 'how clean do you like it?')
    option('-a','there is no long version of this command')
    option('-h','help', &help)
    required('REQ1', 'first required arg')
    required('REQ2', 'second'){|x| "req2:"+x }
    optional('OPT1')
    optional('OPT2','second optional')
  end
  def blearg(req1,req2,opt1,opt2,opts)
    %{#{req1}/#{req2}/#{opt1}/#{opt2}/#{opts.inspect}"}
  end
  cli.does(:no_touch, "this is for testing element reflection" ) do
    option('-c','--cleanliness HOW_CLEAN', 'how clean do you like it?')
    option('-a','there is no long version of this command')
    option('-h','help', &help)
    required('REQ1', 'first required arg')
    required('REQ2', 'second'){|x| "req2:"+x }
    optional('OPT1')
    optional('OPT2','second optional')
  end
  def no_touch(r,r2,o,o2,opts)
    "whatevs"
  end

end

puts AppH7.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
