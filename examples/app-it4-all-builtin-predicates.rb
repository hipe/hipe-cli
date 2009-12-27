#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'
require 'hipe-core/io/all'

class AppIt4
  include Hipe::Cli
  cli.out.klass = Hipe::Io::GoldenHammer
  cli.does('-h','--help')
  cli.default_command = 'help'
  cli.does('go'){
    option('--against-regexp STRING','must match this regexp: letters then digits') {|it|
      it.must_match(/^([a-z]+)([0-9]+)$/)
    }
    option('--against-range NUM','must be btwn 1-10 inclusive') {|it|
      it.must_match(0..10)
    }
    option('--must-be-integer NUM'){|it|
      it.must_be_integer
    }
    option('--must-be-float NUM'){|it|
      it.must_be_float
    }
    option('--must-exist FILENAME'){|it|
      it.must_exist!
    }
    option('--must-not-exist FILENAME'){|it|
      it.must_not_exist!
    }
  }
  def go(opts)
    out = cli.out.new
    out << %{your opts: #{opts.to_hash.inspect}}
    out
  end
end

ret = AppIt4.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
puts ret unless ret.nil?
