#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'


class AppA2
  include Hipe::Cli
  cli.option('-d','--debug','whether we are in debug mode')
  cli.option('-e','--env','the environment')
  cli.default_command = 'go'
  cli.does('go'){|x|
    option('-b','minus b')
  }
  def go(opts)
    opts.inspect
  end
end

puts AppA2.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
