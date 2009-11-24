module Hipe::Cli::Commands
  class Help < CommandGrammar
    def initialize(name, data, logger = nil)
      super :help, {
        :description => 'Show detailed help for a given COMMAND, or general help',
        :optionals => [{:name=>:COMMAND_NAME}]
      }
    end
      
    def parse argv
      command = super argv
      command.extend HelpCommand
      command
    end # def
    
  end # class
  
  module HelpCommand
    def execute
      if command_name.nil? 
        print cli_app_title+": "+@cli_description+"\n\n"
        @cli_command_data = nil; 
        print  %{For help on a specific command, try:\n  #{cli_app_title} help COMMAND\n\n}+
          %{Usage: #{cli_usage_message}\n\n}
      elsif
        command_data.nil?
        print "Sorry, there is no command \"#{command_name}\"\n";
        @cli_command_data = nil; 
        print cli_usage_message
      else
        puts @cli_arguments[:COMMAND_NAME]+":"
        command_data[:name] = command_sym
        puts describe_command_multiline command_data
      end
    end
  end # module 
end # module 
