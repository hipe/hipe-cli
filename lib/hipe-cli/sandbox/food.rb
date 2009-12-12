#!/usr/bin/env ruby
require 'rubygems'
require 'hipe-cli'
require 'ruby-debug'

class Mexican
  VERSION = 'uno.dos.tres'
  include Hipe::Cli::App
  cli.description = "you will have food as if it's from mexico. here."  
  cli.does '-h --help'
  cli.does '-v --version'
  cli.does :burrito, "this is a delcious burrito"
  cli(:out=>:buffer_string)
  def burrito params
    cli.out << "this is your burrito"
  end
  cli.does :taco, "tacos are awesome, everyone loves them.  You should love them too."
  def taco params
    cli.out << "awesome taco time"
  end
  cli.does :enchilada, {:description => "echiladas made by this thing are very awesome because they use "+
  "a time honored tradition of deep frying them in the finest extra virgin corn oil "+
  "that's imported from the outermost region of oaxaca, mexico.",
    :options => { 
      :spiciness => {
        :description => "how hot do you want it (%enum%)",
        :enum => [:mild,:medium,:hot,:flamey],
        :value_name => 'AMT'
      }
    },  
    :required => [
      {:name=>:TYPE, :enum=>[:chicken,:beef,:seitan], :description=>"customers worship our seitan.  "+
        "Seitan was first invented by early english protestant settlers who were escaping persecution by meat eating catholics back home."
      },
      {:name=>:FIRST_NAME, :description=>"the first name of the person receiving the food."}
    ],
    :optionals =>[
      {:name=>  :SIZE, :enum=>[:small,:medium,:large]},
      {:name=>  :TORTILLA, :enum=>[:corn,:flour]}
    ],
    :splat => {
      :name => :EXTRA, :description => 'anything you want to add'
    }    
  }
  def enchilada type, first_name, size, tortilla, opts
    cli.out << "I have one #{type} enchilada for #{name}."
    cli.out << " it is #{size}." if size
    cli.out << " it is on a #{tortilla} tortilla." if tortilla
    cli.out << " it is #{opts[:spiciness]}." if opts[:spiciness]
  end
end

if $PROGRAM_NAME==__FILE__
  mex = Mexican.new
  mex.cli << ARGV
end