#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/')) unless
require 'hipe-cli'

class AppH13
  include Hipe::Cli
  cli.program_name = 'h13'
  cli.default_command = 'help'
  cli.does('-h','--help')
  cli.does("something","description of something") do
    option('-h',&help)
  end
end

puts AppH13.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
