#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'

class AppP1
  include Hipe::Cli
  cli.does(:archipelago)do
     option('--o1 VALUE')
     required('REQ1')
  end
  def archipelago(req1,opts)
    %{archi: "#{req1}", "#{opts[:o1]}"}
  end
end

class AppP2
  include Hipe::Cli
  cli.plugins[:app1] = AppP1
end

class AppP3
  include Hipe::Cli
  cli.plugins[:app2] = AppP2
end

class AppP4
  include Hipe::Cli
  cli.plugin[:app3] = AppP3
  #cli.does '-h','--help'
end

puts AppP4.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__
