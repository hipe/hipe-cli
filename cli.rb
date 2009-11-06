require 'rubygems'
require 'getopt/long'
require 'pp'
require File.dirname(__FILE__)+'/filestuff'

module Markus
  module Cli  
    class SyntaxError < Exception
      def initialize(msg,opts=nil)
        super(msg)
      end
    end
    
    module App
      include Getopt    

      def cli_pre_init
        # the below hold the entire "grammar" and help documentation for the interface of your cli app
        @cliCommands = {}
        @cliGlobalOptions = {}
        
        # the below are the result of parsing the user's input
        @cliCommand = nil
        @cliOptions = {}
        @cliArguments = []

      end
      
      def cli_post_init
        if (@cliCommands[:help].nil?)
          @cliCommands[:help] = {
            :name => :help, # wanky
            :description => 'Show detailed help for a given COMMAND, or general help',
            :arguments => {
              :optional => [
                {:name=>:COMMAND_NAME}
              ]
            }
          }
        end        
        names = []
        self.methods.each do |meth| 
          if ((m = /^cli_execute_(.*)$/.match(meth)) && @cliCommands[m[1].to_sym].nil?)
            @cliCommands[m[1].to_sym] = {:name=>m[1].to_sym, :description=>'(user-defined method)'}
          end
        end
      end
            
      def cli_usage_message
        s = 'Usage: '
        if (@cliCommandData.nil?)
          s << $PROGRAM_NAME +" COMMAND [OPTIONS] [ARGUMENTS]\n" + 
          "commands:\n"
          @cliCommands.each do |key, commandData|
            commandData[:name] = key unless commandData[:name]
            s << "\n  "+describe_command(commandData, :length=>:one_line)
          end
        else
          s << "\n"+describe_command(@cliCommandData)
        end
        s
      end
        
      # the supersyntax for all commands will be: 
      # this-script.rb command-name --opt="x" --opt2="x y" [filename1 [filename2 [...]]] ...    
      def cli_run(argList=nil)

        # so parse out a string not starting with a dash, zero or more ones starting with a dash, 
        # and zero or more not starting with a dash
        argList ||= ARGV
        begin
          @cliCommandData = parse_command   argList
          @cliArguments   = parse_arguments argList
          @cliOptions     = parse_options   argList
        rescue SyntaxError,SoftException => e
          str = e.message+"\n"+cli_usage_message
          puts str
          return
        end
                
        method_name = 'cli_execute_'+(@cliCommandData[:name].to_s)
        
        #puts "\n\nAbout to request #{method_name} with this grammar:\n"; pp @cliCommandData; exit

        __send__(method_name)
      end #def cli_run
      
      # several validations for one value
      def cli_validate(validations, name, value, extra={})
        
        return if (extra[:isOption] && value.nil?) # or iterate over the otpions 
        validations.each do |valData|
          valName = if (valData.instance_of?(Symbol) || valData.instance_of?(String))
            valData.to_s
          else 
            valData[:type].to_s
          end
          methName = 'cli_validate_'+valName

          __send__('cli_validate_'+valName, name, value, valData)
        end
      end
      
      def cli_validate_file_must_exist(name,value,extra)
        FileStuff.file_must_exist(value)
      end

      def cli_validate_regex(validation,varName,varHash)
        #puts "validation; "; pp validation; puts "varname: '#{varName}'";  pp varName; puts "hash: "; pp varHash;
        value = varHash[varName]  
        re = validation[:regex]
        if (! matches = (re.match(value))) 
          raise SyntaxError.new(validation[:message]+' (your value: "'+value+'", re: '+re.to_s+')')
        end
        varHash[varName] = matches # clobbers original ! 
      end
      
      protected
            
      def self.truncate(str,maxLen,ellipses='...')
        if (str.nil?)
          ''
        elsif (str.length <= maxLen)
          str
        elsif (maxLen <= ellipses.length)
          str[0,maxLen]
        else
          str[0,maxLen-ellipses.length-1]+ellipses
        end
      end
      
      def describe_command(commandData, opts={})
        if (opts[:length] && opts[:length]==:one_line)
          descr = commandData[:description].nil? ? '(no description)' : commandData[:description]
          s = sprintf('%-28s',switch( commandData[:name] ))+App.truncate(descr,50)
        else
          parts = []
          args_desc_lines = []
          opts_desc_lines = []
          parts << "\nUsage: \n  #{$PROGRAM_NAME} #{commandData[:name].to_s}"
          
          #cli_populate_global_options(commandData) if (0<@cliGlobalOptions.size)
                    
          if (commandData[:options] && commandData[:options].size > 0)
            parts << "[OPTIONS]"
          end
          if (commandData[:arguments])             
            if (commandData[:arguments][:required])
              commandData[:arguments][:required].each do |v|
                parts << v[:name]
                desc_line = describe_command(v, :length=>:one_line)                
                if (0<desc_line.length)
                  args_desc_lines << desc_line 
                end
              end
            end
            if (commandData[:arguments][:optional])
              last = commandData[:arguments][:optional].size - 1
              commandData[:arguments][:optional].each_with_index do |v,i|
                desc_line = describe_command(v, :length=>:one_line)
                args_desc_lines << desc_line if (0<desc_line.length) 
                s = '['+ switch( v[:name] );
                s << (' ]'*(i+1)) if (i==last)
                parts << s
              end              
            end
          end
          if (commandData[:options])
            commandData[:options].each do |k,v|

                unless (v.instance_of? Hash)
                  pp commandData
                  puts "ls;akfjleskfjesalkfjesak;"
                  exit
                end
                
              opts_desc_lines << sprintf('--%-26s', switch( k )+'=ARG') + 
              (v[:description] ? v[:description] : '')
            end
          end
          sections = []
          grammar = parts.join(' ');
          sections << commandData[:description] if commandData[:description]
          sections << grammar if (grammar.length > 0)
          sections << ("\nArguments:\n\n  "+ args_desc_lines.join("\n  ")) if args_desc_lines.size > 0
          sections << ("\n\nOptions:\n\n  "+ opts_desc_lines.join("\n\n  ")) if opts_desc_lines.size > 0
          sections << "\n"
          s = sections.join("\n");
        end # else show grammar
        if (s.nil?) 
          s = "hwat gives ? "+pp(commandData, opts)
        end
        return s
      end
      
      def cli_populate_global_options(commandData)
        commandData[:options] ||= {}
        commandData[:options].merge!(@cliGlobalOptions) { |key, oldVal, newVal| oldVal.nil? ? newVal : oldVal }
      end 
      
      def parse_command(argList)
        raise SyntaxError.new('Please indicate a command.') if (argList.size==0)
        dirtyCommand = argList.shift
        asSym = switch( dirtyCommand )
        if @cliCommands[asSym].nil?
            raise SyntaxError.new("Sorry, \"#{dirtyCommand}\" is not a valid command.");
        else
          commandData = @cliCommands[asSym].clone
        end
        commandData[:name] = asSym if commandData[:name].nil?  # not sure when we would indicate a :name if ever
        return commandData
      end
        
      def cli_execute_help
        commandName = @cliArguments[:COMMAND_NAME] 
        commandSym = switch( commandName )
        commandData = @cliCommands[commandSym]
        if (commandData.nil?)
          print "Sorry, there is no command \"#{commandName}\"\n";
          @cliCommandData = nil; 
          print cli_usage_message
        else
          puts @cliArguments[:COMMAND_NAME]+":"
          puts describe_command commandData
        end
      end        
      
      def parse_arguments(argList)
        namedArgs = {}
        dirtyArgs = []
        while argList.size > 0 && argList.last[0].chr != '-' do
          dirtyArgs << argList.pop
        end
        dirtyArgs.reverse!
        
        # shlurp all required arguments, barking if they are missing
        if (!@cliCommandData[:arguments].nil? and !@cliCommandData[:arguments][:required].nil? )
          @cliCommandData[:arguments][:required].each do |arg|
            if (dirtyArgs.length == 0)
              raise SyntaxError.new("Missing required argument: "+(arg[:name].to_s), 
                :type     => :missing_required,
                :arg_name => arg[:name]
              )
            end
            value = dirtyArgs.shift
            namedArgs[arg[:name]] = value
            cli_validate( arg[:validations], arg[:name], value ) unless arg[:validations].nil?
          end
        end # if

        # if we have optional arguments, schlurp them up too
        if (!@cliCommandData[:arguments].nil? and !@cliCommandData[:arguments][:optional].nil? )
          names = @cliCommandData[:arguments][:optional].collect{ |x| x[:name] }
          while ( dirtyArgs.size > 0 && names.size > 0 )
            name = names.shift
            namedArgs[name] = dirtyArgs.shift
            cli_validate( arg[:validations], arg[:name], value ) unless  
              @cliCommandData[:arguments][:optional][name][:validations].nil?
          end
        end
        
        # if we have any remaining provided arguments, we have a syntax error
        if (0 < dirtyArgs.length)
          raise SyntaxError.new("Sorry, there were unexpected arguments: \""+dirtyArgs.join(' ')+"\"",
            :type => :extra_arguments,
            :args => dirtyArgs
          )
        end
        return namedArgs
      end
      
      def parse_options(argList)
        cli_populate_global_options @cliCommandData        
        return {} if (@cliCommandData[:options].nil?)
        optsGrammar = []
        @cliCommandData[:options].each do |key,value|
          arr = ['--'+key.to_s.gsub('_','-'), nil, ( value[:getopt_type] || REQUIRED )]
          optsGrammar.push(arr)
        end 
        
        begin
          givenOpts = Long.getopts(*optsGrammar); # splat operator makes an array into a series of arguments
        rescue Getopt::Long::Error => e
          raise SyntaxError.new( e.message )
        end
        
        ppp :GIVENOPS, givenOpts
        
        givenOpts.keys.each{ |k| givenOpts[k.gsub(/-/,'_').to_sym] = givenOpts[k]; givenOpts.delete(k) }
        doTheseKeys = givenOpts.keys & @cliCommandData[:options].keys
        doTheseKeys.each do |k|  
          grammar = @cliCommandData[:options][k]
          if (grammar[:validations])
            grammar[:validations].each do |validation|
              validationMeth = 'cli_validate_'+validation[:type].to_s  #note we don't want it to be option specific
              __send__(validationMeth, validation, k, givenOpts)
            end
          end
        end

        doTheseKeys.each do |k|
          processingMeth = 'cli_process_option_'+k.to_s
          __send__(processingMeth, givenOpts, k)
        end
        return givenOpts
      end
      
      def switch(sym_or_string)
        if sym_or_string.kind_of? Symbol
          sym_or_string.to_s.gsub(/_/,'-')
        elsif sym_or_string.kind_of? String
          sym_or_string.gsub(/-/,'_').to_sym
        else
          sym_or_string
        end
      end
    end #module App
  end #module Cli
end #module Markus