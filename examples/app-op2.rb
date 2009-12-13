#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'
require 'ruby-debug'
require 'optparse/time'

class AppOp2
  include Hipe::Cli
  cli.does(:go) do
    option('-d', '--decibles[BLAH]') do |x|
      %{dB:"#{x}"}
    end
    option('-h') do |x|
      opts.to_s
    end
  end
  def go(opts)
    if opts[:h]
      opts[:h]
    else
      opts.to_s
    end
  end
end

puts AppOp2.new.cli.run(ARGV) if ($PROGRAM_NAME == __FILE__)
