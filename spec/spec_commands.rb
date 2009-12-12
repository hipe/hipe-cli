# bacon spec/commands_spec.rb 
require File.dirname(__FILE__)+'/helpers/test-strap.rb'
require 'hipe-core/struct-diff'
#require 'hipe-cli/extensions/sandbox/basic'


class BasicOne
  include Hipe::Cli::App
  cli.does :blah
  def blah
    cli.out.puts 'blah'
    cli.out
  end
end

describe BasicOne do
  it "the class should populate the blah blah (c1)" do #INTERNAL bad test
    cli = BasicOne.cli
    cli.commands_data.size.should == 1
  end
  it "the class should populate the blah blah (c2)" do
    cli = BasicOne.cli  
    cli.commands.size.should == 1
  end
  it "the object should populate the blah blah (c3)" do #INTERNAL bad test
    cli = BasicOne.new.cli
    cli.commands_data.size.should == 1
  end
  it "the class should populate the blah blah (c4)" do
    cli = BasicOne.new.cli  
    cli.commands.size.should == 1
  end  
  it "aliases (c5)" do # INTERNAL bad test
    cli = BasicOne.new.cli
    cli.commands.aliases.should == {:blah => :blah, 'blah' => :blah}  
  end  
  
end


class BasicTwo
  include Hipe::Cli::App
  cli.does :blah
  cli.does '-h --help'
  def blah
    cli.out.puts 'blah'
    cli.out
  end
end


describe BasicTwo do
  it "the class should populate the blah blah (c2-1)" do #INTERNAL bad test
    cli = BasicTwo.cli
    cli.commands_data.size.should == 2
  end
  it "the class should populate the blah blah (c2-2)" do
    cli = BasicTwo.cli  
    cli.commands.size.should == 2
  end
  it "the object should populate the blah blah (c2-3)" do #INTERNAL bad test
    cli = BasicTwo.new.cli
    cli.commands_data.size.should == 2
  end
  it "the class should populate the blah blah (c2-4)" do
    cli = BasicTwo.new.cli  
    cli.commands.size.should == 2
  end  
  it "aliases (c2-5)" do # INTERNAL bad test
    cli = BasicTwo.new.cli
    target = {
      :blah       => :blah, 
      'blah'      => :blah,
      '-h'        => '-h --help',
      '--help'    => '-h --help',
      :help       => '-h --help',
      '-h --help' => '-h --help',
      'help'      => '-h --help'      
    }
    have = cli.commands.aliases 
    diff_desc = Hipe::StructDiff.diff(target, have).summarize
    diff_desc.should == '(none)'
  end
end
