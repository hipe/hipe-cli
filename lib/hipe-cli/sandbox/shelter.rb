#!/usr/bin/env ruby
require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'


class PluginB
  include Hipe::Cli::App
  cli.does :sing, { }
  def sing 
    cli.out.puts "la la la la la la la"
  end
end

class PluginA
  include Hipe::Cli::App
  cli.plugin :beta, PluginB
  cli.does :shout, { }
  def shout
    cli.out.puts "i'm shouting out loud"
  end
end

module SomeModule
  class PluginC; include Hipe::Cli::App; end
end

class MyPluginyApp
  include Hipe::Cli::App
  cli.description = "Every human needs shelter from the elements.  Yours will be bright and fulfilling."
  cli.plugin :alpha, PluginA
  #cli.plugin :beta, PluginB
  cli.plugin :gamma, Hipe::Cli::DIR+'/spec/fakes/some-plugin.rb'
  cli.plugin :delta, Hipe::Cli::DIR+'/spec/fakes/plugind'
  cli.plugin :class_not_there, Hipe::Cli::DIR+'/fakes/some-plugin-empty'
  cli.plugin :file_not_there, Hipe::Cli::DIR+'/not/there'
  cli.does :bark, {}
  cli.does '-h --help'
  cli.does '-v --version'
  def bark
    puts "barking"
  end
end # MyPluginyApp

if $PROGRAM_NAME==__FILE__
  app = MyPluginyApp.new
  app.cli << ARGV
end
