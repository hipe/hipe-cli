require 'rubygems'
require 'getopt/long'

module Hipe
  module Cli
    # base class for all exceptions
    class CliException < Exception; end

    # user input errors
    # soft errors for user to see.  
    class SoftException < CliException; end 
    
    # something we don't expect to go wrong (well obviously we do a little bit)
    # for errors related to parsing command grammars, etc.  Endusers shouldn't see these.
    class HardException < CliException; end

    # user types a prefix for an unknown plugin
    class PluginNotRegisteredException < SoftException; end     
    
    # failure to load a plugin 
    class PluginNotFoundException < HardException; end
    
    class CommandNotFound < SoftException; end
    
    class SyntaxError < SoftException; end    
    
  end
end
require 'hipe-cli/app'