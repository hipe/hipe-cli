require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'
require 'bacon'


class MainApp
  include Hipe::Cli::App
  
  cli.does :bark, {
    :description => "this is the sound a dog makes",
    :options => { :the_volume => {}, :mood => {} },
    :required => [{:name=>'target'}, {:name=>'req2'}],
    :optionals => [{:name=>'optl1'},{:name=>'optl2'}],
    :splat => {:minimum => 1}
  }
  def bark request
    @out.puts "barking"
  end
end

shared "a cli app" do
  before do
    @app = MainApp.new
  end  
end


def shell! string  #really dangerous! executes anything in the shell.
  command ||= %{ruby #{File.dirname(__FILE__)}/argv.rb}
  Marshal.load %x{#{command} #{string}}
end
