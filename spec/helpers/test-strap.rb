require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'
require 'bacon'

def shell! string  #really dangerous! executes anything in the shell.
  command ||= %{ruby #{File.dirname(__FILE__)}/argv.rb}
  Marshal.load %x{#{command} #{string}}
end
