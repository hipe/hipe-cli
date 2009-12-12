require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'
require 'bacon'

module Bacon
 class Context 
   def skipit(description, &block)
     puts %{- SKIPPING #{description}}
   end
  end
end

def shell! string  #really dangerous! executes anything in the shell.
  command ||= %{ruby #{File.dirname(__FILE__)}/argv.rb}
  Marshal.load %x{#{command} #{string}}
end
