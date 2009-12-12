#!/usr/bin/env ruby
require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'

#class Other
#  include Hipe::Cli::App
#  cli.does :other
#  def other
#    cli.out.puts 'other'
#    cli.out
#  end
#end
class Basic
  include Hipe::Cli::App
  #cli.plugin "the-other", Other
  cli.does '-h --help'
  cli.does :blah
  def blah
    cli.out.puts 'blah'
    cli.out
  end
end

if $PROGRAM_NAME==__FILE__
  app = Basic.new
  app.cli << ARGV
end

