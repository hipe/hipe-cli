#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'
require 'ruby-debug'
require 'optparse/time'

class AppOp4
  include Hipe::Cli
  cli.does(:go) do
    option('-h', '--help', 'you guessed it'){|x| puts opts; exit }
    option('-a',  '--an-option BLAH', 'some whatever option')
    required 'MOVIE', 'your favorite movie'
    required 'FOOD', 'a food you love'
  end
  def go(movie, food, opts)
    debugger
    'x'
  end
end

puts AppOp4.new.cli.run(ARGV) if ($PROGRAM_NAME == __FILE__)
